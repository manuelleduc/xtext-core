package org.eclipse.xtext.xtext.generator.mbase

import java.util.Set
import org.eclipse.xtext.AbstractRule
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.GrammarUtil
import org.eclipse.xtext.xtext.UsedRulesFinder
import static extension org.eclipse.xtext.xtext.generator.util.GrammarUtil2.*
class MbaseUsageDetector {
	
	def boolean inheritsXtype(Grammar grammar) {
		grammar.inherits('org.eclipse.xtext.mbase.Xtype')
	}
	
	def boolean inheritsMbase(Grammar grammar) {
		grammar.inherits('org.eclipse.xtext.mbase.Mbase')
	}

	def boolean inheritsMbaseWithAnnotations(Grammar grammar) {
		grammar.inherits('org.eclipse.xtext.mbase.annotations.MbaseWithAnnotations')
	}

	def boolean usesXImportSection(Grammar grammar) {
		val Set<AbstractRule> usedRules = newHashSet
		new UsedRulesFinder(usedRules).compute(grammar)
		return usedRules.exists [
			name == 'XImportSection' && GrammarUtil.getGrammar(it).name == 'org.eclipse.xtext.mbase.Xtype'
		]
	}

}