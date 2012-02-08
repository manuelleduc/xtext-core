/*******************************************************************************
 * Copyright (c) 2012 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.generator.trace;

import java.util.List;

import org.eclipse.jdt.annotation.NonNull;

/**
 * @author Sebastian Zarnekow - Initial contribution and API
 */
public interface ITraceRegionProvider {

	@NonNull List<AbstractTraceRegion> getTraceRegions(int relativeOffset, AbstractTraceRegion parent);
	
}
