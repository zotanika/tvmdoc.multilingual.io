ή    /                      g        u       d  €  @   	    J  n  Ο  :   >     y          §  &  »  ω   β	  D  ά
  G  !    i      β     €   y  {     Θ        c  P  ώ  ₯  O    υ  (        ½     έ  e  ό     b  \  ο     L  £  α  %     ,  «!  Ό   Ψ"  ¦   #  η   <$  ¨   $%  q   Ν%     ?&     Τ&     Y'    Z)  {  γ*    _,  S  w-  j   Λ.     6/  )   D/  ο  n/  X   ^1  Κ  ·1    3  Q   5     q5     5     5  =  ―5    ν6  Ά  ς7    ©:  J  8<    =  β   >  κ   v?  Δ   a@  ο   &A  Η   B    ήB  ₯  tD  #  F  '   >H     fH     H  Ο  ‘H  Ώ   qJ  \  1K     M    #N    ©Q  R  <S  	  T  ρ   U  7  V  Ϊ   ΓW     X  ·   $Y  ²   άY  ½  Z  ζ  M]  λ  4_  u   a   *Note: please see the documentation on the :ref:`pass-infra` for more specific detail on this subject.* AST Traversers Adding a Compiler Pass to Relay And that's all we need. It is very common to define a public interface that performs some bookkeeping before invoking the top-level recursion. We could of course further wrap the API by making a standalone procedure that creates a ``CallChecker`` instance and calls ``Check`` on it, but the takeaway is that we've achieved our goal with very little effort. At a high level, there are two key components to writing a pass: Compiler passes are the primary interface for both extending Relay's feature set and for performing optimizations on Relay programs. By writing a compiler pass, you can modify the AST or collect information about the AST, depending on your goal. Indeed, some of Relay's most important built-in features (e.g., autodiff and type inference) are nothing more than "standard" compiler passes. Constant folding involves evaluating expressions in the program that only involve constant values, then replacing those expressions with the result of evaluating them. The goal of this pass is to frontload all of the computations that we can. To achieve this, the constant folding pass makes use of a visitor (``ConstantChecker``) and a mutator (``ConstantFolder``). Creating one or more C++ classes that traverse the program Example: Constant Folding Expression Mutators Expression Visitors If the ``Pass`` object produced by the above code is given to the pass infrastructure, it will ensure that the AST traversal is applied to every function in the given Relay module, which is the behavior one would expect for a constant folding pass (it should fold all constants where possible). In order to better understand the process of writing a pass, we will look at the constant folding pass (found in `src/relay/transforms/fold_constant.cc`_) as a guide, because it is a relatively simple pass that incorporates both types of traversals. In the ``CallNode`` case, we first use the ``VisitExpr_`` of ``ExprMutator`` to visit the call, which const-folds all of the fields of the call. We use ``ExprMutator::VisitExpr_`` instead of ``VisitExpr``, because we want to bypass the vtable (to avoid an infinite loop) and use the default implementation provided by ``ExprMutator``. Then we evaluate the call only if all of the arguments are constant (using ``ConstantChecker``). Evaluating the call produces a **value**, so we use a helper method ``ValueToExpr`` to allow us to place the evaluated expression back into the AST. In the ``LetNode`` case, we first attempt to const-fold the value being bound in the expression. If we can, then we populate ``memo_`` and return the result of visiting the body---essentially, propagating the bound value to its use sites in the body. If we can't const-fold the bound value, we mimic the default implementation. In the ``TupleItemGetNode`` case, we check if ``op->tuple`` field is a ``TupleNode``. If so, we replace the tuple get with the field of the tuple pointed to by ``op->index``. The reason we need to check is because ``op->tuple`` might evaluate to a tuple, without itself being a tuple. More detail about registration can be found in :ref:`tvm-runtime-system` and more information about the pass manager interface can be found in :ref:`pass-infra`. Relay's standard passes are listed in `include/tvm/relay/transform.h`_ and implemented in `src/relay/pass/`_. Note that the ``PassContext`` object contains information a pass uses for error reporting and configuration options; ``FoldConstant`` does not need this information but other passes may reference their ``PassContext`` objects. Note that the returned expression will not necessarily be an ``IfNode``, and this is fine, because the return type is ``Expr``. Now, we create the public interface: Note that we're calling ``VisitExpr`` and not ``VisitExpr_`` here, so we can use the vtable in ``ExprFunctor`` for routing. Now, if we wanted to write a class ``CallChecker`` that checks if any function calls appear in the program, we would only need to extend ``ExprVisitor`` and define the following ``VisitExpr_`` method: Now, if we wanted to write a class ``IfCollapser`` that replaces every if statement with its true branch, we would override ``VisitExpr_`` for ``IfNode``: Now, we construct a more convenient interface ``FoldConstant`` for our constant folder. ``FoldConstant`` is a standalone function outside of the ``ConstantFolder`` class that takes an expression and internally creates and uses a ``ConstantFolder`` instance (the full definition can be found in `src/relay/transforms/fold_constant.cc`_). Once ``Pass`` objects are defined in the above fashion, they can be invoked using the pass infrastructure's ``Sequential`` construct, which takes a list of passes and applies them in sequence to a Relay module, obtaining a transformed module as a result. For example, the below code applies both the ``FoldConstant`` and ``ToANormalForm`` passes (one after the other) to each function in ``mod`` and obtains a new module. One feature ``ExprMutator`` has that ``ExprVisitor`` doesn't is a built-in ``memo_`` field for caching results. It makes sense that ``ExprMutator`` has a memoizer, because we know which types of results we're caching (i.e., ``Expr``), whereas the visit methods of ``ExprVisitor`` don't return anything. Usually, when we want to cache results in a subclass of ``ExprVisitor``, we need to define the cache ourselves. Registering a Pass with the Pass Manager The ``ConstantChecker`` Visitor The ``ConstantFolder`` Mutator The base class used to traverse Relay programs is ``ExprFunctor``. The public interface it provides is a ``VisitExpr`` method that takes an expression and zero or more arguments and returns an instance of some type. When you extend this class, you define the AST traversal pattern by overriding implementations of ``VisitExpr_`` for each type of expression. The bookkeeping used to coordinate these definitions is a ``Check`` method that returns whether the given expression is considered constant. The function ``CreateFunctionPass`` allows for registering the optimization level of the pass (in this case, 2), which can be used to group together passes based on their general utility, a name for the pass, and any dependencies for the pass. A pass's dependencies are given as a list of any passes whose results are necessary to be able to run the current pass. ``FoldConstant`` does not have any dependencies, but many Relay passes do depend on having type information, so ``InferType`` is a common dependency; others may depend on the program's being in A-normal form, via the ``ToANormalForm`` pass. The pass can now be invoked via the pass infrastructure, though it's a good idea to also add a Python binding for the pass, as in this code snippet: The relation between ``VisitExpr`` and ``VisitExpr_`` has to do with dispatch. Each ``VisitExpr_`` definition targets a specific type of expression, but you don't always know which node type you'll be visiting. To remedy this, ``ExprFunctor`` provides a ``VisitExpr`` function which routes from the given expression to the ``VisitExpr_`` case that handles it. Although C++ already provides dynamic dispatch, ``ExprFunctor`` defines its own vtable, which ``VisitExpr`` uses. By defining our own vtable, we have more control over dispatch. For example, if we wanted to define a ``PrintVisitor`` traverser that printed "Here" before every visit, we could override ``VisitExpr``: There are a few things to notice here. First, ``Mutate`` is an alias for ``VisitExpr`` in ``ExprMutator``. Second, we only return a new node if the call to ``Mutate`` modified the ``tuple`` field. This method of update is called a functional update and doing so avoids unnecessary allocations. This mutator performs the bulk of the constant folding pass and internally uses ``ConstantChecker``. In Relay, there are three node types that are involved in constant folding: ``LetNode``, ``TupleItemGetNode``, and ``CallNode``. In the following paragraphs, we explain the roles of each in the pass. This visitor is used to check if an expression is constant. In Relay, we define an expression to be constant if it is a ``ConstantNode`` or it is a ``TupleNode`` with only constant fields. To begin, we'll give an overview of the key mechanisms for writing a compiler pass. Then, we'll walk through a concrete example of the constant-folding pass in Relay. We don't modify ``memo_`` for every node we encounter; instead we only modify ``memo_`` when the encountered node could potentially be constant. Then we rely on the default value being false when ``memo_`` doesn't contain ``expr``. We use a ``memo_`` field to map from nodes to whether they are constant and to cache these results. Below are the ``VisitExpr_`` definitions in the ``ConstantChecker``. With the AST traversers written, the pass can be registered to become a TVM API endpoint with the following code: With this mutator, we didn't need to do any bookkeeping, but we still want to follow the convention of having a descriptive method as the interface. Wrapping the traversal implementation and its metadata in the pass manager API so it can neatly interface with the :ref:`pass-infra` ``ExprFunctor`` itself is a very general class, which is why more often than not, you will be extending ``ExprVisitor`` or ``ExprMutator``. These classes extend ``ExprFunctor`` and provide default implementations of ``VisitExpr_`` that capture common traversal patterns for each expression type. Having these default implementations means we only need to provide overriding implementations for the expression types where we want different behavior. We describe each subclass on its own in the following sections. ``ExprMutator`` is for passes that transform the program in some way. With this class, ``VisitExpr`` and its private counterparts return ``Expr``. The default ``VisitExpr_`` implementations provided by this class visit all of the expression's fields that are expressions and set the fields to be the result of visiting them. The default implementation for ``TupleGetItemNode`` is shown below. ``ExprVisitor`` is for passes that don't modify the program and instead perform program analyses and collect information. With this class, ``VisitExpr`` and the private counterparts return nothing. The ``VisitExpr_`` implementations provided by this class simply visit all of the expression's fields that are expressions. The default implementation for ``IfNode`` is shown below. where ``result_`` is a field. In this case, we don't need to further recurse on the fields of the ``CallNode``, because ``result_`` is already true and we now know the original expression contains a call. To make this visitor usable, we would provide the following public method: Project-Id-Version: tvm 0.8.dev0
Report-Msgid-Bugs-To: 
POT-Creation-Date: 2021-01-04 20:34+0900
PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE
Last-Translator: FULL NAME <EMAIL@ADDRESS>
Language: kr
Language-Team: kr <LL@li.org>
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: 8bit
Generated-By: Babel 2.9.0
 *μλ¦Ό: λ³Έ μ£Όμ μ κ΄λ ¨λ λ μμΈν λ΄μ©μ :ref:`pass-infra` μ λ¬Έμλ₯Ό μ°Έκ³ νμΈμ.* AST μνμ Relayμ μ»΄νμΌλ¬ ν¨μ€ μΆκ°νκΈ° μ΄κ²μΌλ‘ νμν κ²μ λ€ κ°μΆ°μ‘μ΅λλ€. μ΄λ μ΅μμ κ³μΈ΅μμ μ¬κ·λ₯Ό κ°μνκΈ° μ μ λͺλͺ λΆν€νμ μνμν€κ³ μ νλ κ³΅κ° μΈν°νμ΄μ€λ₯Ό μ μν  λμ μμ£Ό νν κ³Όμ μλλ€. λ¬Όλ‘  ``CallChecker`` μΈμ€ν΄μ€λ₯Ό μμ±νκ³  κ·Έμ λν΄ ``Check`` λ₯Ό νΈμΆνλ λλ¦½μ μΈ νλ‘μμ Έλ₯Ό λ§λ€μ΄ APIλ₯Ό ν¬μ₯ν  μλ μκ² μΌλ, μ€μν κ²μ μμ£Ό μ μ λΈλ ₯μΌλ‘ μ°λ¦¬ λͺ©νλ₯Ό λ¬μ±νλ€λ μ μλλ€.  κ³ μμ€μμ, ν¨μ€λ₯Ό μμ±νκΈ° μν λ κ°μ§ μ€μ μμκ° μμ΅λλ€: μ»΄νμΌλ¬ ν¨μ€λ Relayμ κΈ°λ₯ μΆκ°μ Relay νλ‘κ·Έλ¨ μμ μ΅μ νλ₯Ό μννκΈ° μν μ£Όμ μΈν°νμ΄μ€μλλ€. μ»΄νμΌλ¬ ν¨μ€λ₯Ό μμ±ν¨μΌλ‘μ¨ λͺ©μ μ λ°λΌμλ ASTλ₯Ό λ³κ²½νκ±°λ ASTμ λν μ λ³΄λ₯Ό μμ§ν  μ μμ΅λλ€. μ¬μ€, Relayμ κ°μ₯ μ€μν λͺλͺ λΉνΈμΈ κΈ°λ₯ (e.g., μλλΉκ΅μ νμ μΆλ‘ )λ€μ‘°μ°¨λ "νμ€" μ»΄νμΌλ¬ ν¨μ€μ μ€μλμ λ―ΈμΉμ§ λͺ»ν©λλ€.  μμ ν΄λ©μ νλ‘κ·Έλ¨ λ΄μ ννμλ€μ΄ **μ€μ§** μμκ°λ€νκ³ λ§ κ΄λ ¨λμ΄ μλμ§λ₯Ό νκ°νκ³ , ννμλ€μ νκ°ν κ²°κ³Όλ¬Όλ‘ κ΅μ²΄ν©λλ€. μ΄ ν¨μ€μ λͺ©μ μ λ―Έλ¦¬ κ³μ°ν  μ μλ κ²λ€μ λͺ¨λ μλΉκ²¨ ν΄λλ κ²μλλ€. μ΄λ₯Ό μν΄, μμ ν΄λ© ν¨μ€λ λ°©λ¬Έμ (``ConstantChecker``) μ λ³μ΄μ (``ConstantFolder``) λ₯Ό μ΄μ©ν©λλ€.  νλ‘κ·Έλ¨ μ μ²΄λ₯Ό μννλ νλ μ΄μμ C++ ν΄λμ€λ₯Ό λ§λ€ κ². μμ : μμ ν΄λ© ννμ λ³μ΄μ ννμ λ°©λ¬Έμ μκΈ°μ μ½λλ‘ λ§λ€μ΄μ§ ``Pass`` κ°μ²΄κ° ν¨μ€ μΈνλΌμ€νΈλ­μ³μ μ£Όμ΄μ§λ©΄, μμ ν΄λ© ν¨μ€μκ² κΈ°λλλ λμ κ·Έλλ‘ μ£Όμ΄μ§ Relay λͺ¨λ λ΄μ λͺ¨λ  ν¨μμ AST μνκ° μ μ©λλ€λ κ²μ΄ λ³΄μ¦λ©λλ€(κ°λ₯ν λΆλΆμμ λͺ¨λ  μμκ° μ ν κ²μλλ€).  ν¨μ€λ₯Ό μμ±νλ κ³Όμ μ λ μ μ΄ν΄νκΈ° μν΄, λ νμμ μνλ€μ΄ μνΈ μμ©νλ λΉκ΅μ  κ°λ¨ν ν¨μ€μΈ μμ ν΄λ© ν¨μ€λ₯Ό μλ²μ μΌλ‘ μ΄ν΄λ³΄λλ‘ νκ² μ΅λλ€(`src/relay/transforms/fold_constant.cc` μ°Έμ‘°).  ``CallNode`` μ κ²½μ°, λ¨Όμ  νΈμΆμ λ°©λ¬ΈνκΈ° μν΄ ``ExprMutator`` μ ``VisitExpr_`` λ₯Ό μ¬μ©νλλ°, μ΄λ νΈμΆμ μ°κ΄λ λͺ¨λ  νλλ₯Ό μμ-ν΄λν©λλ€. ``VisitExpr`` λμ  ``ExprMutator::VisitExpr_`` λ₯Ό μ¬μ©νλ μ΄μ λ vtableμ μ°ννκΈ° μΆμ΄μμ΄κ³ (λ¬΄ν λ£¨ν ννΌλ₯Ό μν΄) ``ExprMutator`` μ μν΄ μ κ³΅λλ κΈ°λ³Έ κ΅¬νμ νμ©νκΈ° μν¨μλλ€. κ·Έ λ€μ λͺ¨λ  μΈμκ° μμ( ``ConstantChecker`` λ₯Ό μ΄μ©ν΄)μΈμ§ μ¬λΆλ‘ νΈμΆμ νκ°ν©λλ€. νΈμΆμ νκ°λ νλμ **κ°** μΌλ‘ μ°μΆλκ³ , ν¬νΌ λ©μλ ``ValueToExpr`` λ₯Ό μ΄μ©ν΄ νκ°λ ννμμ ASTλ‘ λλλ € λ³΄λλλ€.  ``LetNode`` μ κ²½μ°, ννμμ κ΅¬μλ κ°λ€μ λν΄ μμ-ν΄λλ₯Ό λ¨Όμ  μλν΄ λ΄λλ€. κ·Έκ² κ°λ₯νλ€λ©΄, ``memo_`` μ λ§μ°κΈ° νκ³ , λͺΈμ²΄ λ°©λ¬Έ κ²°κ³Όλ₯Ό λ°ννλλ°---μ΄λ νμ°μ μΌλ‘ κ΅¬μ κ°λ€μ λͺΈμ²΄ λ΄μ μ¬μ©μ²λ‘ λͺ¨λ μ ννκ² λ©λλ€. λ§μΌ κ΅¬μλ κ°λ€μ μμ-ν΄λν  μ μλ€λ©΄, κΈ°λ³Έ κ΅¬νμ λͺ¨λ°©ν©λλ€.  ``TupleItemGetNode`` μ κ²½μ°, ``op->tuple`` νλκ° ``TupleNode`` μΈμ§λ₯Ό νμΈν©λλ€. λ§μΌ κ·Έλ λ€λ©΄, ν¨νμ ``op->index`` κ° κ°λ¦¬ν€λ ννμ νλλ‘ κ΅μ²΄ν©λλ€. νμΈμ΄ νμν μ΄μ λ ``op->tuple`` μ΄ ννμ νκ°ν  λΏ μ€μ€λ‘λ ννμ΄ μλ μλ μκΈ° λλ¬Έμλλ€.  More detail about registration can be found in :ref:`tvm-runtime-system` and more information about the pass manager interface can be found in :ref:`pass-infra`. Relay's standard passes are listed in `include/tvm/relay/transform.h`_ and implemented in `src/relay/pass/`_. Note that the ``PassContext`` object contains information a pass uses for error reporting and configuration options; ``FoldConstant`` does not need this information but other passes may reference their ``PassContext`` objects. λ°νλ ννμμ λ°λμ ``IfNode`` λ μλ μ μλ€λ κ²μ μ μνμΈμ. λ°ν νμμ ``Expr`` μ΄μ΄μΌ νλ―λ‘, μ΄λ μ ν λ¬Έμ κ° μλλλ€. μ΄μ  κ³΅κ° μΈν°νμ΄μ€λ₯Ό μμ±νκ² μ΅λλ€:  μ¬κΈ°μ ``VisitExpr_`` κ° μλ ``VisitExpr`` μ νΈμΆνλ€λ μ μ μ μνμΈμ. λ°λΌμ μ°λ¦¬λ κ²½λ‘ μΆμ μ μν΄ ``ExprFunctor`` μ vtableμ μ¬μ©ν  μ μμ΅λλ€.  λ§μΌ, νλ‘κ·Έλ¨ λ΄μμ ν¨μ νΈμΆμ΄ μλμ§ νμΈνλ ν΄λμ€ ``CallChecker`` λ₯Ό μμ±νκ³ μ νλ€λ©΄, ``ExprVisitor`` λ₯Ό νμ₯ν΄μ λ€μκ³Ό κ°μ΄ ``VisitExpr_`` λ©μλλ₯Ό μ μνκΈ°λ§ νλ©΄ λ©λλ€: λ§μΌ, λͺ¨λ  if κ΅¬λ¬Έμ μ°Έ-κ°μ§(true branch)λ‘ κ΅μ²΄νλ ν΄λμ€ ``IfCollapser`` λ₯Ό μμ±νκ³ μ νλ€λ©΄, ``IfNode`` μ λν΄ ``VisitExpr_`` λ₯Ό μ€λ²λΌμ΄λν΄μΌ ν©λλ€:  μ΄μ , μ°λ¦¬μ μμ ν΄λ© κΈ°λ₯μ μν΄ λ³΄λ€ νΈλ¦¬ν μΈν°νμ΄μ€μΈ ``FoldConstant`` λ₯Ό κ΅¬μΆν΄ λ³΄κ² μ΅λλ€. ``FoldConstant`` λ ``ConstantFolder`` ν΄λμ€μ λλ¦½λ ν¨μλ‘, ννμμ μ·¨νκ³  λ΄λΆμ μΌλ‘ ``ConstantFolder`` μΈμ€ν΄μ€λ₯Ό μμ± λ° νμ©ν©λλ€(μλ²½ν μ μλ `src/relay/transforms/fold_constant.cc`_ μμ μ°Ύμλ³Ό μ μμ΅λλ€).  Once ``Pass`` objects are defined in the above fashion, they can be invoked using the pass infrastructure's ``Sequential`` construct, which takes a list of passes and applies them in sequence to a Relay module, obtaining a transformed module as a result. For example, the below code applies both the ``FoldConstant`` and ``ToANormalForm`` passes (one after the other) to each function in ``mod`` and obtains a new module. ``ExprMutator`` μλ μμ§λ§ ``ExprVisitor`` μλ μλ ν κ°μ§ κΈ°λ₯μ κ²°κ³Όκ°μ μΊμ±νκΈ° μν λΉνΈμΈ ``memo_`` νλμλλ€. ``ExprMutator`` κ° λ©λͺ¨μ΄μ λ₯Ό λ³΄μ νλ κ²μ, μ°λ¦¬κ° μ΄λ€ νμμ κ²°κ³Όκ°μ μΊμ±ν μ§(i.e., ``Expr``) μκΈ° λλ¬Έμ νλΉν©λλ€. λ°λ©΄μ ``ExprVisitor`` μ λ°©λ¬Έ λ©μλλ μλ¬΄ κ²λ λ°ννμ§ μμ£ . ν΅μ, ``ExprVisitor`` μ μλΈν΄λμ€ λ΄μμ κ²°κ³Όκ°μ μΊμ±νκ³ μ ν  λμλ μ€μ€λ‘ μ§μ  μΊμλ₯Ό μ μν΄μΌ ν©λλ€.  ν¨μ€ λ§€λμ λ‘ ν¨μ€ λ±λ‘νκΈ° ``ConstantChecker`` λ°©λ¬Έμ ``ConstantFolder`` λ³μ΄μ Relay νλ‘κ·Έλ¨μ μννκΈ° μν΄ μ¬μ©λλ λ² μ΄μ€ ν΄λμ€λ ``ExprFunctor`` μλλ€. μ΄ ν΄λμ€κ° μ κ³΅νλ κ³΅κ° μΈν°νμ΄μ€λ ``VisitExpr`` λ©μλλ‘, ννμκ³Ό μΆκ°μ μΈ μΈμ(μλ΅ κ°λ₯)λ₯Ό λ°μ νΉμ  νμμ μΈμ€ν΄μ€λ₯Ό λ°νν©λλ€. μ΄ ν΄λμ€λ₯Ό νμ₯νλ €λ©΄, κ° νμμ ννμμ λν ``VisitExpr_`` κ΅¬νμ μ€λ²λΌμ΄λ©ν¨μΌλ‘μ¨ AST μν ν¨ν΄μ μ μν΄μΌ ν©λλ€.  μ΄λ€ μ μλ₯Ό μ‘°μ¨νκΈ° μν΄ μ¬μ©λλ λΆν€ν κΈ°λ₯μ κ΅¬νμ²΄κ° ``Check`` λ©μλλ‘, μ£Όμ΄μ§ ννμμ λΆλ³μΌλ‘ λ³Ό μ μλμ§μ μ¬λΆλ₯Ό λ°νν©λλ€.  The function ``CreateFunctionPass`` allows for registering the optimization level of the pass (in this case, 2), which can be used to group together passes based on their general utility, a name for the pass, and any dependencies for the pass. A pass's dependencies are given as a list of any passes whose results are necessary to be able to run the current pass. ``FoldConstant`` does not have any dependencies, but many Relay passes do depend on having type information, so ``InferType`` is a common dependency; others may depend on the program's being in A-normal form, via the ``ToANormalForm`` pass. The pass can now be invoked via the pass infrastructure, though it's a good idea to also add a Python binding for the pass, as in this code snippet: ``VisitExpr`` κ³Ό ``VisitExpr_`` κ³Όμ κ΄κ³λ μμ£Ό λ°μ ν©λλ€. κ°κ°μ ``VisitExpr_`` μ μλ νΉμ ν νμμ ννμμ λ€λ£¨μ§λ§, μ΄λ€ νμμ λΈλμ λ°©λ¬Έν  κ²μΈμ§ μΈμ λ μ μ μλ κ²μ μλλλ€. μ΄ λ¬Έμ λ₯Ό μ²λ¦¬νκΈ° μν΄ ``ExprFunctor`` κ° μ κ³΅νλ κ²μ΄ ``VisitExpr`` ν¨μλ‘, μ£Όμ΄μ§ ννμμ κ·Έκ²μ λ€λ£° μ€ μλ μ μ ν ``VisitExpr_`` λ‘ λΌμ°νν©λλ€. C++μ΄ μ΄λ―Έ λμ  λμ€ν¨μΉλ₯Ό μ κ³΅ν¨μλ λΆκ΅¬νκ³ , ``ExprFunctor`` μ ``VisitExpr`` μ΄ μ¬μ©νλ μμ²΄ vtableμ λ΄μ₯νλλ‘ μ μλ©λλ€. μ΄λ₯Ό ν΅ν΄ λμ€ν¨μΉ λμμ μμ΄μ λ λ§μ μ μ΄κΆμ κ°κ² λ©λλ€. μλ₯Ό λ€μ΄, λ§€ λ°©λ¬Έ μ μ "Here" λΌκ³  νλ¦°νΈνλ ``PrintVisitor`` λΌλ μνμλ₯Ό μ μνκ³  μΆλ€λ©΄, ``VisitExpr`` λ₯Ό λ€μκ³Ό κ°μ΄ μ€λ²λΌμ΄λν  μ μμ΅λλ€:  μΌλμ λ¬μΌ ν  μ λ€μ΄ λͺ κ° μμ΅λλ€. μ²«λ²μ§Έ, ``Mutate`` λ ``ExprMutator`` λ΄μ ``VisitExpr`` μ λν λ³μΉ­μλλ€. λλ²μ§Έ, ``Mutate`` λ‘μ νΈμΆμ΄ ``tuple`` νλλ₯Ό λ³κ²½ν  λμλ§ μλ‘μ΄ λΈλλ₯Ό λ°νν©λλ€. μ΄ μλ°μ΄νΈ λ°©λ²μ ν¨μμ  μλ°μ΄νΈ(functional update)λΌκ³  λΆλ₯΄λ©°, λΆνμν ν λΉμ μ΅μ νλλ‘ μλν©λλ€.  μ΄ λ³μ΄μλ μμ ν΄λ© ν¨μ€ λ­μΉλ₯Ό μννκ³  λ΄λΆμ μΌλ‘ ``ConstantChecker`` λ₯Ό νμ©ν©λλ€. Relayμμλ μμ ν΄λ©κ³Ό κ΄λ ¨λ μΈκ°μ§ νμμ λΈλκ° μμ΅λλ€: ``LetNode``, ``TupleItemGetNode``, κ·Έλ¦¬κ³  ``CallNode``. μ΄μ΄μ§λ λ¨λ½μμ κ°κ°μ μ­ν μ λν΄ μ€λͺνκ² μ΅λλ€. μ΄ λ°©λ¬Έμλ μ΄λ€ ννμμ΄ λΆλ³λμΈμ§μ μ¬λΆλ₯Ό νμΈνκΈ° μν΄ μ¬μ©λ©λλ€. Relayμμλ, μ΄λ€ ννμμ΄ ``ConstantNode`` μ΄κ±°λ μμ νλλ‘λ§ μ΄λ£¨μ΄μ§ ``TupleNode`` μ΄λΌλ©΄ λΆλ³λ, μ¦ μμλ‘ μ μν©λλ€.  μμνκΈ°μ μμ, μ»΄νμΌλ¬ ν¨μ€λ₯Ό μμ±νκΈ° μν ν΅μ¬ λ©μ»€λμ¦μ λν κ°μλ₯Ό μ΄ν΄λ³Ό κ²μλλ€. κ·Έ ν, Relay λ΄μ μμ ν΄λ©μ κ΅¬μ²΄μ μΈ μμ λ‘ μΌμ μ°¨κ·Ό μ°¨κ·Ό μ§μ΄ λκ°κ² μ΅λλ€.  λ§μ£ΌμΉ λͺ¨λ  λΈλμ λν΄ ``memo_`` λ₯Ό λ³κ²½νμ§λ μμΌλ©°, μ€μ§ κ·Έ λΈλκ° μ μ μ μΌλ‘ λΆλ³μΌ λμλ§ ``memo_`` λ₯Ό λ³κ²½ν©λλ€. κ·Έλ¬λ―λ‘ ``memo_`` κ° ``expr`` μ λν λ΄μ©μ μλ‘νκ³  μμ§ μμ λμλ κΈ°λ³Έκ°μ κ±°μ§μΌλ‘ κ°μ£Όν  μ μμ΅λλ€.  ``memo_`` νλλ μ΄λ€ λΈλλ₯Ό κ·Έ λΈλκ° μμμΈμ§μ μ¬λΆμ λμμν€κ³  κ²°κ³Όλ₯Ό μΊμ±ν΄ λκΈ° μν΄ μ¬μ©λ©λλ€. μλλ ``ConstantChecker`` λ΄μμμ ``VisitExpr_`` μ μμλλ€. AST μνμκ° μμ±λμλ€λ©΄, μ΄ ν¨μ€κ° TVM APIμ μ§κ²°λλλ‘ λ€μκ³Ό κ°μ μ½λλ‘ λ±λ‘λ  μ μμ΅λλ€:  μ΄ λ³μ΄μμμλ μ΄λ€ λΆν€νλ νμ μμμ΅λλ€. νμ§λ§ μ°λ¦¬λ μ¬μ ν μΈν°νμ΄μ€λ‘μ μμ μ  λ©μλλ₯Ό κ°λ κ·μ½μ λ°λ₯΄κ³ μ ν©λλ€.  μν κ΅¬νμ²΄μ κ·Έμ μμνλ ν¨μ€ λ§€λμ  API λ΄μ λ©νλ°μ΄ν°λ₯Ό ν¨κ» ν¬μ₯νμ¬ :ref:`pass-infra` μ μ ν©μ μΌλ‘ μΈν°νμ΄μ€λλλ‘ ν  κ². ``ExprFunctor`` μμ²΄λ λ§€μ° μΆμνλ ν΄λμ€μ΄κΈ° λλ¬Έμ, μ΄λ₯Ό μ§μ  νμ©νκΈ°λ³΄λ€λ ``ExprVisitor`` λ ``ExprMutator`` λ₯Ό νμ₯νλ κ²½μ°κ° λΉλ²ν  κ²μλλ€. μ΄λ€ ν΄λμ€λ€μ΄ ``ExprFunctor`` λ₯Ό νμ₯νμ¬ κ° ννμ νμλ€μ λν κ³΅ν΅μ μΈ μν ν¨ν΄μ λ€λ£¨λ ``VisitExpr_`` μ κΈ°λ³Έμ μΈ κ΅¬νμ μ κ³΅νκ² λ©λλ€. κΈ°λ³Έ κ΅¬νλ€μ λ³΄μ νκ³  μλ€λ κ²μ, μ¦, μ΄λ€ ννμ νμμ λν΄ λ€λ₯Έ λμμ νκΈΈ μν  λμ κ·Έ κ²½μ°λ§ μ€λ²λΌμ΄λ©νμ¬ λ€λ£¨λλ‘ κ΅¬ννκΈ°λ§ νλ©΄ λλ€λ λ»μλλ€. λ΄μ₯λ μλΈν΄λμ€μ λν΄μλ λ€μ μΉμμμ μμ νκ² μ΅λλ€.  ``ExprMutator`` λ ν¨μ€λ€λ‘ νμ¬κΈ μ΄λ€ λ°©μμΌλ‘λ  νλ‘κ·Έλ¨μ λ³νμν΅λλ€. μ΄ ν΄λμ€μμ ``VisitExpr`` μ κ·Έμ λ΄λΆμ μΌλ‘ λμνλ ν¨μλ€μ΄ ``Expr`` λ₯Ό λ°νν©λλ€. μ΄ ν΄λμ€μ μν΄ μ κ³΅λλ ``VisitExpr`` κΈ°λ³Έ κ΅¬νμ ννμμ μν ννμ νλλ€μ λͺ¨λ λ°©λ¬Ένκ³  ν΄λΉ νλλ€μ λ°©λ¬Έμ κ²°κ³Όλ¬Όλ‘ κ΅μ²΄ν©λλ€. ``TupleGetItemNode`` μ λν κΈ°λ³Έ κ΅¬νμ²΄λ μλμ κ°μ΅λλ€.  ``ExprVisitor`` λ νλ‘κ·Έλ¨μ λ³κ²½νμ§ μλ λμ  νλ‘κ·Έλ¨ λΆμμ μννκ³  μ λ³΄λ₯Ό λͺ¨μΌλ ν¨μ€λ€μ μν κ²μλλ€. μ΄ ν΄λμ€μμλ ``VisitExpr`` μ κ·Έμ λ΄λΆμ μΌλ‘ λμνλ ν¨μλ€μ΄ μλ¬΄κ²λ λ°ννμ§ μμ΅λλ€. μ΄ ν΄λμ€μ μν΄ μ κ³΅λλ ``VisitExpr_`` κ΅¬νλ€μ κ°λ¨ν ννμμ μν ννμ νλλ€μ λͺ¨λ λ°©λ¬Έν©λλ€. ``IfNode`` μ λν κΈ°λ³Έ κ΅¬νμ²΄λ μλμ κ°μ΅λλ€.  μ¬κΈ°μ ``result_`` λ νλμλλ€. μ΄ κ²½μ°μ, ``CallNode`` μ νλ μμμ λ μ΄μμ μ¬κ·λ λΆνμν©λλ€. ``result_`` κ° μ΄λ―Έ μ°Έμ΄κ³  μ΄μ  μλμ ννμμ νΈμΆμ΄ ν¬ν¨λλ€λ κ²μ μκΈ° λλ¬Έμλλ€. μ΄ λ°©λ¬Έμκ° μ¬μ©λ  μ μλλ‘ νλ €λ©΄, λ€μκ³Ό κ°μ κ³΅κ° λ©μλλ₯Ό μ κ³΅ν΄μΌ ν  κ²λλ€:  