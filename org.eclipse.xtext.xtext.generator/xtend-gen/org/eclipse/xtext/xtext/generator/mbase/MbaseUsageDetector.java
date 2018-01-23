package org.eclipse.xtext.xtext.generator.mbase;

import com.google.common.base.Objects;
import java.util.Set;
import org.eclipse.xtext.AbstractRule;
import org.eclipse.xtext.Grammar;
import org.eclipse.xtext.GrammarUtil;
import org.eclipse.xtext.xbase.lib.CollectionLiterals;
import org.eclipse.xtext.xbase.lib.Functions.Function1;
import org.eclipse.xtext.xbase.lib.IterableExtensions;
import org.eclipse.xtext.xtext.UsedRulesFinder;
import org.eclipse.xtext.xtext.generator.util.GrammarUtil2;

@SuppressWarnings("all")
public class MbaseUsageDetector {
  public boolean inheritsXtype(final Grammar grammar) {
    return GrammarUtil2.inherits(grammar, "org.eclipse.xtext.mbase.Xtype");
  }
  
  public boolean inheritsMbase(final Grammar grammar) {
    return GrammarUtil2.inherits(grammar, "org.eclipse.xtext.mbase.Mbase");
  }
  
  public boolean inheritsMbaseWithAnnotations(final Grammar grammar) {
    return GrammarUtil2.inherits(grammar, "org.eclipse.xtext.mbase.annotations.MbaseWithAnnotations");
  }
  
  public boolean usesXImportSection(final Grammar grammar) {
    final Set<AbstractRule> usedRules = CollectionLiterals.<AbstractRule>newHashSet();
    new UsedRulesFinder(usedRules).compute(grammar);
    final Function1<AbstractRule, Boolean> _function = (AbstractRule it) -> {
      return Boolean.valueOf((Objects.equal(it.getName(), "XImportSection") && Objects.equal(GrammarUtil.getGrammar(it).getName(), "org.eclipse.xtext.mbase.Xtype")));
    };
    return IterableExtensions.<AbstractRule>exists(usedRules, _function);
  }
}
