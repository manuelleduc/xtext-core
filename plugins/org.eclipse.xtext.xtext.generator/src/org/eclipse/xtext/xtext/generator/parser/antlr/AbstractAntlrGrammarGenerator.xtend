/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xtext.generator.parser.antlr

import com.google.inject.Inject
import org.eclipse.xtext.AbstractElement
import org.eclipse.xtext.AbstractRule
import org.eclipse.xtext.Action
import org.eclipse.xtext.Alternatives
import org.eclipse.xtext.Assignment
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.EnumLiteralDeclaration
import org.eclipse.xtext.EnumRule
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.Group
import org.eclipse.xtext.Keyword
import org.eclipse.xtext.ParserRule
import org.eclipse.xtext.RuleCall
import org.eclipse.xtext.TerminalRule
import org.eclipse.xtext.UnorderedGroup
import org.eclipse.xtext.xtext.FlattenedGrammarAccess
import org.eclipse.xtext.xtext.RuleFilter
import org.eclipse.xtext.xtext.RuleNames
import org.eclipse.xtext.xtext.generator.CodeConfig
import org.eclipse.xtext.xtext.generator.XtextGeneratorNaming
import org.eclipse.xtext.xtext.generator.grammarAccess.GrammarAccessExtensions
import org.eclipse.xtext.xtext.generator.model.IXtextGeneratorFileSystemAccess

import static extension org.eclipse.xtext.GrammarUtil.*
import static extension org.eclipse.xtext.xtext.generator.parser.antlr.AntlrGrammarGenUtil.*
import static extension org.eclipse.xtext.xtext.generator.parser.antlr.TerminalRuleToLexerBody.*

abstract class AbstractAntlrGrammarGenerator {
	
	@Inject
	protected extension XtextGeneratorNaming
	
	@Inject
	protected extension GrammarAccessExtensions
	
	@Inject CodeConfig codeConfig
	
	KeywordHelper keyWordHelper
	
	def generate(Grammar it, AntlrOptions options, IXtextGeneratorFileSystemAccess fsa) {
		this.keyWordHelper = KeywordHelper.getHelper(it)
		val RuleFilter filter = new RuleFilter();
		filter.discardUnreachableRules = options.skipUnusedRules
		val RuleNames ruleNames = RuleNames.getRuleNames(it, true);
		val Grammar flattened = new FlattenedGrammarAccess(ruleNames, filter).getFlattenedGrammar();
		fsa.generateFile(grammarNaming.getParserGrammar(it).grammarFileName, flattened.compileParser(options))
		if (!isCombinedGrammar) {
			fsa.generateFile(grammarNaming.getLexerGrammar(it).grammarFileName, flattened.compileLexer(options))
		}
	}
	
	protected def isCombinedGrammar() {
		true
	}
	
	protected abstract def GrammarNaming getGrammarNaming()
	
	protected def compileParser(Grammar it, AntlrOptions options) '''
		�codeConfig.fileHeader�
		�IF !combinedGrammar�parser �ENDIF�grammar �grammarNaming.getParserGrammar(it).simpleName�;
		�compileParserOptions(options)�
		�IF isCombinedGrammar�
			�compileTokens(options)�
		�ENDIF�
		�IF isCombinedGrammar�
			�compileLexerHeader(options)�
		�ENDIF�
		�compileParserHeader(options)�
		�compileParserMembers(options)�
		�compileRuleCatch(options)�
		�compileRules(options)�
	'''
	
	protected def compileLexer(Grammar it, AntlrOptions options) '''
		�codeConfig.fileHeader�
		lexer grammar �grammarNaming.getLexerGrammar(it).simpleName�;
		�compileLexerOptions(options)�
		�compileTokens(options)�
		�compileLexerHeader(options)�
		�compileKeywordRules(options)�
		�compileTerminalRules(options)�
	'''
	
	protected def compileParserOptions(Grammar it, AntlrOptions options) '''
		options {
			�IF !isCombinedGrammar�
				tokenVocab=�grammarNaming.getLexerGrammar(it).simpleName�;
			�ENDIF�
			�IF internalParserSuperClass != null�
				superClass=�internalParserSuperClass�;
			�ENDIF�
			�IF options.backtrack || options.memoize || options.k >= 0�
				�IF options.backtrack�
					backtrack=true;
				�ENDIF�
				�IF options.memoize�
					memoize=true;
				�ENDIF�
				�IF options.k >= 0�
					memoize=�options.k�;
				�ENDIF�
			�ENDIF�
		}
	'''
	protected def compileLexerOptions(Grammar it, AntlrOptions options) '''
		�IF options.backtrackLexer�
			options {
				backtrack=true;
				memoize=true;
			}
		�ENDIF�
	'''
	
	protected def String getInternalParserSuperClass() {
		null
	}
	
	protected def compileTokens(Grammar it, AntlrOptions options) '''
		�IF options.isBacktrackLexer�
			tokens {
				�FOR kw : allKeywords.sort.sortBy[length]�
					�keyWordHelper.getRuleName(kw)�;
				�ENDFOR�
				�FOR rule: allTerminalRules�
					�rule.ruleName�;
				�ENDFOR�
			}
		�ENDIF�
	'''
	
	protected def compileLexerHeader(Grammar it, AntlrOptions options) '''
		
		@�IF isCombinedGrammar�lexer::�ENDIF�header {
		package �grammarNaming.getLexerGrammar(it).packageName�;
		�compileLexerImports(options)�
		}
	'''
	
	protected def compileLexerImports(Grammar it, AntlrOptions options) '''
		
		// Hack: Use our own Lexer superclass by means of import. 
		// Currently there is no other way to specify the superclass for the lexer.
		import org.eclipse.xtext.parser.antlr.Lexer;
	'''
	
	protected def compileParserHeader(Grammar it, AntlrOptions options) '''
		
		@�IF isCombinedGrammar�parser::�ENDIF�header {
		package �grammarNaming.getParserGrammar(it).packageName�;
		�compileParserImports(options)�
		}
	'''
	
	protected def compileParserImports(Grammar it, AntlrOptions options) {
		''
	}
	
	protected def compileParserMembers(Grammar it, AntlrOptions options) {
		''
	}
	
	protected def compileRuleCatch(Grammar it, AntlrOptions options) {
		''
	}
	
	protected def compileRules(Grammar it, AntlrOptions options) '''
		�FOR rule:allParserRules.filter[rule | rule.isCalled(it)]�
			
			�rule.compileRule(it, options)�
		�ENDFOR�
		�FOR rule:allEnumRules.filter[rule | rule.isCalled(it)]�
			
			�rule.compileRule(it, options)�
		�ENDFOR�
		�IF isCombinedGrammar�
			�compileTerminalRules(options)�
		�ENDIF�
	'''
	
	protected def compileKeywordRules(Grammar it, AntlrOptions options) {
		val allKeywords = allKeywords.sort.sortBy[-length]
		val allTerminalRules = allTerminalRules
		
		'''
			�IF options.isBacktrackLexer�
				SYNTHETIC_ALL_KEYWORDS :
				�FOR kw: allKeywords.indexed�
					(FRAGMENT_�keyWordHelper.getRuleName(kw.value)�)=> FRAGMENT_�keyWordHelper.getRuleName(kw.value)� {$type = �keyWordHelper.getRuleName(kw.value)�; } 
					�IF kw.key != allKeywords.size || !allTerminalRules().isEmpty�|�ENDIF�
				�ENDFOR�
				�FOR rule : allTerminalRules.indexed�
					�IF !isSyntheticTerminalRule(rule.value) && !rule.value.fragment�
						(FRAGMENT_�rule.value.ruleName()�)=> FRAGMENT_�rule.value.ruleName()� {$type = �rule.value.ruleName()�; }
						�IF rule.key != allTerminalRules.size�|�ENDIF�
					�ENDIF�
				�ENDFOR�
				;
				�FOR kw:  allKeywords�
					fragment FRAGMENT_�keyWordHelper.getRuleName(kw)� : '�kw.toAntlrString()�';
				�ENDFOR�
			�ELSE�
				�FOR rule:allKeywords�
					
					�rule.compileKeyword(it, options)�
				�ENDFOR�
			�ENDIF�
		'''
	}
	
	protected def compileTerminalRules(Grammar it, AntlrOptions options) '''
		�IF options.isBacktrackLexer�
			�FOR rule:allTerminalRules�
				
				�rule.compileBacktrackingRule(it, options)�
			�ENDFOR�
		�ELSE�
			�FOR rule:allTerminalRules�
				
				�rule.compileRule(it, options)�
			�ENDFOR�
		�ENDIF�
	'''
	
	protected def compileRule(EnumRule it, Grammar grammar, AntlrOptions options) {
		compileEBNF(options)
	}
	
	protected def compileRule(ParserRule it, Grammar grammar, AntlrOptions options) {
		compileEBNF(options)
	}
	
	protected def compileRule(TerminalRule it, Grammar grammar, AntlrOptions options) '''
		�IF isSyntheticTerminalRule(it)�
			fragment �ruleName� : ;
		�ELSE�
			�IF fragment�fragment �ENDIF��ruleName� : �toLexerBody��IF shouldBeSkipped(grammar)� {skip();}�ENDIF�;
		�ENDIF�
	'''
	
	protected def compileBacktrackingRule(TerminalRule it, Grammar grammar, AntlrOptions options) '''
		�IF !isSyntheticTerminalRule(it)�
			�IF fragment�
				fragment �ruleName� : �toLexerBody�;
			�ELSE�
				fragment �ruleName� : FRAGMENT_�ruleName�;
				fragment FRAGMENT_�ruleName� : �toLexerBody�;
			�ENDIF�
		�ENDIF�
	'''
	
	protected def compileKeyword(String keyWord, Grammar grammar, AntlrOptions options) '''
		�keyWordHelper.getRuleName(keyWord)� : �keyWord.toAntlrKeyWordRule(options)�;
	'''
		
	protected def toAntlrKeyWordRule(String keyWord, AntlrOptions options) {
		 "'" + if (options.ignoreCase) keyWord.toAntlrStringIgnoreCase else keyWord.toAntlrString + "'"
	}
	protected def shouldBeSkipped(TerminalRule it, Grammar grammar) {
		grammar.initialHiddenTokens.contains(ruleName) && isCombinedGrammar
	}
	
	protected def String compileEBNF(AbstractRule it, AntlrOptions options) '''
		// Rule �originalElement.name�
		�ruleName��compileInit(options)�:
			�IF it instanceof ParserRule && originalElement.datatypeRule�
				�dataTypeEbnf(alternatives, true)�
			�ELSE�
				�ebnf(alternatives, options, true)�
			�ENDIF�
		;
		�compileFinally(options)�
	'''
		
	protected def compileInit(AbstractRule it, AntlrOptions options) {
		''
	}
		
	protected def compileFinally(AbstractRule it, AntlrOptions options) {
		''
	}
		
	protected def String ebnf(AbstractElement it, AntlrOptions options, boolean supportActions) '''
		�IF mustBeParenthesized�(
			�ebnfPredicate(options)��ebnf2(options, supportActions)�
		)�ELSE��ebnf2(options, supportActions)��ENDIF��cardinality�
	'''
	
	protected def String ebnfPredicate(AbstractElement it, AntlrOptions options) '''
		�IF predicated() || firstSetPredicated�(�IF predicated()��predicatedElement.ebnf2(options, false)��ELSE��FOR e:firstSet SEPARATOR ' | '��e.ebnf2(options, false)��ENDFOR��ENDIF�)=>�ENDIF�
	'''
	
	protected def String dataTypeEbnf(AbstractElement it, boolean supportActions) '''
		�IF mustBeParenthesized�(
			�dataTypeEbnfPredicate��dataTypeEbnf2(supportActions)�
		)�ELSE��dataTypeEbnf2(supportActions)��ENDIF��cardinality�
	'''
	
	protected def String dataTypeEbnfPredicate(AbstractElement it) '''
		�IF predicated() || firstSetPredicated�(�IF predicated()��predicatedElement.dataTypeEbnf2(false)��ELSE��FOR e:firstSet SEPARATOR ' | '��e.dataTypeEbnf2(false)��ENDFOR��ENDIF�)=>�ENDIF�
	'''
	
	protected dispatch def String dataTypeEbnf2(AbstractElement it, boolean supportActions) '''ERROR �eClass.name� not matched'''

	protected dispatch def String dataTypeEbnf2(Alternatives it, boolean supportActions) '''
		�FOR e:elements SEPARATOR '\n    |'��e.dataTypeEbnf(supportActions)��ENDFOR�
	'''

	protected dispatch def String dataTypeEbnf2(Group it, boolean supportActions) '''
		�FOR e:elements��e.dataTypeEbnf(supportActions)��ENDFOR�
	'''
	
	protected dispatch def String dataTypeEbnf2(UnorderedGroup it, boolean supportActions) '''
		(�FOR e:elements SEPARATOR '\n    |'��e.dataTypeEbnf2(supportActions)��ENDFOR�)*
	'''
	
	protected dispatch def String dataTypeEbnf2(Keyword it, boolean supportActions) {
		if (combinedGrammar) "'" + value.toAntlrString + "'" else keyWordHelper.getRuleName(value)
	}
	
	protected dispatch def String dataTypeEbnf2(RuleCall it, boolean supportActions) {
		rule.ruleName
	}
	
	protected dispatch def String ebnf2(AbstractElement it, AntlrOptions options, boolean supportActions) '''ERROR �eClass.name� not matched'''
	
	protected dispatch def String ebnf2(Alternatives it, AntlrOptions options, boolean supportActions) '''
		�FOR element:elements SEPARATOR '\n    |'��element.ebnf(options, supportActions)��ENDFOR�
	'''
	
	protected dispatch def String ebnf2(Group it, AntlrOptions options, boolean supportActions) '''
		�FOR element:elements��element.ebnf(options, supportActions)��ENDFOR�
	'''
	
	protected dispatch def String ebnf2(UnorderedGroup it, AntlrOptions options, boolean supportActions) '''
		(�FOR element:elements SEPARATOR '\n    |'��element.ebnf(options, supportActions)��ENDFOR�)*
	'''
	
	protected dispatch def String ebnf2(Assignment it, AntlrOptions options, boolean supportActions) '''
		�terminal.assignmentEbnf(it, options, supportActions)�
	'''
	
	protected dispatch def String ebnf2(Action it, AntlrOptions options, boolean supportActions) {
		''
	}
	
	protected dispatch def String ebnf2(Keyword it, AntlrOptions options, boolean supportActions) {
		if (combinedGrammar) "'" + value.toAntlrString + "'" else keyWordHelper.getRuleName(value) 
	}
	
	protected dispatch def String ebnf2(RuleCall it, AntlrOptions options, boolean supportActions) {
		rule.ruleName
	}
	
	protected dispatch def String ebnf2(EnumLiteralDeclaration it, AntlrOptions options, boolean supportActions) {
		"'" + literal.value.toAntlrString + "'"
	}
	
	protected dispatch def String crossrefEbnf(AbstractElement it, CrossReference ref, boolean supportActions) {
		throw new IllegalStateException("crossrefEbnf is not supported for " + it)
	}
	
	protected dispatch def String crossrefEbnf(Alternatives it, CrossReference ref, boolean supportActions) '''
		�FOR element:elements SEPARATOR '\n    |'��element.crossrefEbnf(ref, supportActions)��ENDFOR�
	'''
	
	protected dispatch def String crossrefEbnf(RuleCall it, CrossReference ref, boolean supportActions) {
		val rule = rule
		if (rule instanceof ParserRule) {
			if (!(rule.originalElement as AbstractRule).datatypeRule) {
				throw new IllegalStateException("crossrefEbnf is not supported for ParserRule that is not a datatype rule")
			}
		}
		rule.crossrefEbnf(it, ref, supportActions)
	}
	
	protected def String crossrefEbnf(AbstractRule it, RuleCall call, CrossReference ref, boolean supportActions) {
		switch it {
			EnumRule,
			ParserRule,
			TerminalRule: 
				ruleName
			default:
				throw new IllegalStateException("crossrefEbnf is not supported for " + it)
		}
	}
	
	protected dispatch def String assignmentEbnf(Group it, Assignment assignment, AntlrOptions options, boolean supportActions) {
		throw new IllegalStateException("assignmentEbnf is not supported for " + it)
	}
	
	protected dispatch def String assignmentEbnf(Assignment it, Assignment assignment, AntlrOptions options, boolean supportActions) {
		throw new IllegalStateException("assignmentEbnf is not supported for " + it)
	}
	
	protected dispatch def String assignmentEbnf(Action it, Assignment assignment, AntlrOptions options, boolean supportActions) {
		throw new IllegalStateException("assignmentEbnf is not supported for " + it)
	}
	
	protected dispatch def String assignmentEbnf(Alternatives it, Assignment assignment, AntlrOptions options, boolean supportActions) '''
		�FOR element:elements SEPARATOR '\n    |'��element.assignmentEbnf(assignment, options, supportActions)��ENDFOR�
	'''
	
	protected dispatch def String assignmentEbnf(RuleCall it, Assignment assignment, AntlrOptions options, boolean supportActions) {
		switch rule : rule {
			EnumRule,
			ParserRule,
			TerminalRule: 
				rule.ruleName
			default: 
				throw new IllegalStateException("assignmentEbnf is not supported for " + rule)
		}
	}
	
	protected dispatch def String assignmentEbnf(CrossReference it, Assignment assignment, AntlrOptions options, boolean supportActions) {
		terminal.crossrefEbnf(it, supportActions)
	}
	
	protected dispatch def String assignmentEbnf(AbstractElement it, Assignment assignment, AntlrOptions options, boolean supportActions) {
		ebnf(options, supportActions)
	}
	
	def dispatch mustBeParenthesized(AbstractElement it) {
		predicated() || firstSetPredicated
	}
	
	def dispatch mustBeParenthesized(Group it) {
		predicated() || firstSetPredicated || cardinality != null
	}
	
	def dispatch mustBeParenthesized(Alternatives it) {
		predicated() || firstSetPredicated || cardinality != null
	}
}