/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xtext.generator.mbase

import com.google.inject.Inject
import org.eclipse.xtext.xtext.generator.AbstractXtextGeneratorFragment

class XtypeGeneratorFragment2 extends AbstractXtextGeneratorFragment {

	@Inject extension MbaseUsageDetector
	
	override generate() {
		if (language.grammar.inheritsXtype && projectConfig.eclipsePlugin.manifest !== null)
			projectConfig.eclipsePlugin.manifest.requiredBundles += 'org.eclipse.xtext.mbase.ui'
	}
	
}
