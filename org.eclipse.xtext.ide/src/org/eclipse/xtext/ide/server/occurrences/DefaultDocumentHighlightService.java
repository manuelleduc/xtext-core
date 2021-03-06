/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.ide.server.occurrences;

import static java.util.Collections.*;
import static org.eclipse.xtext.util.ITextRegionWithLineInformation.*;

import java.util.List;

import org.apache.log4j.Logger;
import org.eclipse.core.runtime.NullProgressMonitor;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.lsp4j.DocumentHighlight;
import org.eclipse.lsp4j.DocumentHighlightKind;
import org.eclipse.lsp4j.TextDocumentPositionParams;
import org.eclipse.xtext.findReferences.IReferenceFinder;
import org.eclipse.xtext.findReferences.IReferenceFinder.Acceptor;
import org.eclipse.xtext.findReferences.TargetURICollector;
import org.eclipse.xtext.findReferences.TargetURIs;
import org.eclipse.xtext.ide.server.Document;
import org.eclipse.xtext.ide.util.DocumentHighlightComparator;
import org.eclipse.xtext.nodemodel.ICompositeNode;
import org.eclipse.xtext.parser.IParseResult;
import org.eclipse.xtext.resource.EObjectAtOffsetHelper;
import org.eclipse.xtext.resource.ILocationInFileProvider;
import org.eclipse.xtext.resource.IReferenceDescription;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.util.ITextRegion;
import org.eclipse.xtext.util.ITextRegionWithLineInformation;

import com.google.common.base.Predicate;
import com.google.common.base.Supplier;
import com.google.common.base.Suppliers;
import com.google.common.collect.FluentIterable;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableList.Builder;
import com.google.inject.Inject;
import com.google.inject.Provider;
import com.google.inject.Singleton;

/**
 * Default implementation of the {@link IDocumentHighlightService document
 * highlight service}.
 * 
 * @author akos.kitta - Initial contribution and API
 */
@Singleton
public class DefaultDocumentHighlightService implements IDocumentHighlightService {

	private static final Logger LOGGER = Logger.getLogger(DefaultDocumentHighlightService.class);

	/**
	 * Placeholder document version.
	 */
	private static final int UNUSED_VERSION = -1;

	/**
	 * Filters all elements that does not have {@link EObject#eContainer()
	 * container}.
	 */
	private static final Predicate<EObject> AST_ROOT_FILTER = obj -> obj.eContainer() != null;

	@Inject
	protected EObjectAtOffsetHelper offsetHelper;

	@Inject
	protected ILocationInFileProvider locationInFileProvider;

	@Inject
	private Provider<TargetURIs> targetURIsProvider;

	@Inject
	private IReferenceFinder referenceFinder;

	@Inject
	private TargetURICollector uriCollector;

	@Inject
	private ITextRegionTransformer textRegionTransformer;

	@Inject
	private DocumentHighlightComparator comparator;

	@Override
	public List<? extends DocumentHighlight> getDocumentHighlights(Document document, XtextResource resource, TextDocumentPositionParams params, CancelIndicator cancelIndicator) {
		int offset = document.getOffSet(params.getPosition());
		return getDocumentHighlights(resource, offset);
	}

	@Override
	public List<DocumentHighlight> getDocumentHighlights(final XtextResource resource, final int offset) {

		if (resource == null) {
			if (LOGGER.isDebugEnabled()) {
				LOGGER.warn("Resource was null.");
			}
			return emptyList();
		}

		final URI uri = resource.getURI();
		if (offset < 0) {
			if (LOGGER.isDebugEnabled()) {
				LOGGER.warn("Invalid offset argument. Offset must be a non-negative integer for resource: " + uri);
			}
			return emptyList();
		}

		final IParseResult parseResult = resource.getParseResult();
		if (parseResult == null) {
			if (LOGGER.isDebugEnabled()) {
				LOGGER.warn("Parse result was null for resource: " + uri);
			}
			return emptyList();
		}

		final ICompositeNode rootNode = parseResult.getRootNode();
		final String docContent = rootNode.getText();
		final int docLength = docContent.length();
		if (offset >= docLength) {
			if (LOGGER.isDebugEnabled()) {
				LOGGER.warn("Offset exceeds document lenght. Document was " + docLength + " and offset was: " + offset
						+ " for resource: " + uri);
			}
			return emptyList();
		}

		final EObject selectedElemnt = offsetHelper.resolveElementAt(resource, offset);
		if (!isDocumentHighlightAvailableFor(selectedElemnt, resource, offset)) {
			return emptyList();
		}

		final Supplier<Document> docSupplier = Suppliers.memoize(() -> new Document(UNUSED_VERSION, docContent));
		Iterable<URI> targetURIs = getTargetURIs(selectedElemnt);
		if (!(targetURIs instanceof TargetURIs)) {
			final TargetURIs result = targetURIsProvider.get();
			result.addAllURIs(targetURIs);
			targetURIs = result;
		}

		final Builder<DocumentHighlight> resultBuilder = ImmutableList.<DocumentHighlight>builder();
		final Acceptor acceptor = (Acceptor2) (source, sourceURI, eReference, index, targetOrProxy, targetURI) -> {
			final ITextRegion region = locationInFileProvider.getSignificantTextRegion(source, eReference, index);
			if (!isNullOrEmpty(region)) {
				resultBuilder.add(textRegionTransformer.apply(docSupplier.get(), region, DocumentHighlightKind.Read));
			}
		};
		referenceFinder.findReferences((TargetURIs) targetURIs, resource, acceptor, new NullProgressMonitor());

		if (resource.equals(selectedElemnt.eResource())) {
			final ITextRegion region = locationInFileProvider.getSignificantTextRegion(selectedElemnt);
			if (!isNullOrEmpty(region)) {
				resultBuilder.add(textRegionTransformer.apply(docSupplier.get(), region, DocumentHighlightKind.Write));
			}
		}

		return FluentIterable.from(resultBuilder.build()).toSortedList(comparator);
	}

	/**
	 * Returns with {@code true} if the AST element selected from the resource
	 * can provide document highlights, otherwise returns with {@code false}.
	 * 
	 * <p>
	 * Clients may override this method to change the default behavior.
	 * 
	 * @param selectedElemnt
	 *            the selected element resolved via the offset from the
	 *            resource. Can be {@code null}.
	 * @param resource
	 *            the resource for the document.
	 * @param offset
	 *            the offset of the selection.
	 * 
	 * @return {@code true} if the document highlight is available for the
	 *         selected element, otherwise {@code false}.
	 *
	 */
	protected boolean isDocumentHighlightAvailableFor(final EObject selectedElemnt, final XtextResource resource,
			final int offset) {

		if (selectedElemnt == null || !getSelectedElementFilter().apply(selectedElemnt)) {
			return false;
		}

		final EObject containedElement = offsetHelper.resolveContainedElementAt(resource, offset);
		// Special handling to avoid such cases when the selection is not
		// exactly on the desired element.
		if (selectedElemnt == containedElement) {
			final ITextRegion region = locationInFileProvider.getSignificantTextRegion(containedElement);
			return !isNullOrEmpty(region)
					// Region is comparable to a selection in an editor,
					// therefore the end position is exclusive.
					&& (region.contains(offset) || (region.getOffset() + region.getLength()) == offset);
		}

		return true;
	}

	/**
	 * Returns with a filter that is used to ignore elements at a given offset.
	 * <p>
	 * By default returns with a filter that skips all {@link EObject} instances
	 * that have no {@link EObject#eContainer() eContainer()}.
	 * 
	 * @return a function that will be used to skip elements selected on the
	 *         given offset.
	 */
	protected Predicate<EObject> getSelectedElementFilter() {
		return AST_ROOT_FILTER;
	}

	/**
	 * Returns with an iterable of URIs that points to all elements that are
	 * referenced by the argument or vice-versa.
	 * 
	 * @return an iterable of URIs that are referenced by the argument or the
	 *         other way around.
	 */
	protected Iterable<URI> getTargetURIs(final EObject primaryTarget) {
		final TargetURIs result = targetURIsProvider.get();
		uriCollector.add(primaryTarget, result);
		return result;
	}

	/**
	 * Returns {@code true} if the argument is either {@code null} or
	 * {@link ITextRegionWithLineInformation#EMPTY_REGION empty}. Otherwise
	 * returns with {@code false}.
	 * 
	 * @return {@code true} if the argument is either {@code null} or empty.
	 */
	protected boolean isNullOrEmpty(final ITextRegion region) {
		return region == null || EMPTY_REGION == region;
	}

	/**
	 * Sugar for lambda.
	 */
	@FunctionalInterface
	private static interface Acceptor2 extends Acceptor {

		@Override
		default void accept(final IReferenceDescription description) {
			// Does not accept any reference descriptions because local
			// references are announced per object.
		}

	}

}