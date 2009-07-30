package org.eclipse.xtext.grammaranalysis.impl;

import org.eclipse.emf.common.notify.Adapter;
import org.eclipse.xtext.AbstractElement;
import org.eclipse.xtext.grammaranalysis.INFAState;
import org.eclipse.xtext.grammaranalysis.IGrammarNFAProvider.NFABuilder;

public abstract class AbstractCachingNFABuilder<S, T> implements
		NFABuilder<S, T> {

	protected abstract S createState(AbstractElement ele);

	protected abstract T createTransition(S source, S target, boolean isRuleCall);

	public boolean filter(AbstractElement ele) {
		return false;
	}

	@SuppressWarnings("unchecked")
	public final S getState(AbstractElement ele) {
		if (ele == null)
			return null;
		for (Adapter a : ele.eAdapters())
			if (a instanceof INFAState) {
				INFAState s = (INFAState) a;
				if (s.getBuilder() == this)
					return (S) s;
			}
		S t = createState(ele);
		ele.eAdapters().add((Adapter) t);
		return t;
	}

	public final T getTransition(S source, S target, boolean isRuleCall) {
		return createTransition(source, target, isRuleCall);
	}
}
