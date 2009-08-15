-----------------------------------------------------------------------------
-- |
-- Module      : Ministg.State
-- Copyright   : (c) 2009 Bernie Pope 
-- License     : BSD-style
-- Maintainer  : bjpop@csse.unimelb.edu.au
-- Stability   : experimental
-- Portability : ghc
--
-- Representation of the state of the ministg evaluator.
-----------------------------------------------------------------------------

module Ministg.State 
   ( Continuation (..)
   , Stack
   , prettyStack 
   , Heap 
   , EvalState (..)
   , Eval
   , Style (..)
   , initStack
   , initHeap
   , initState
   , pushCallStack
   , setCallStack
   , lookupHeap
   , lookupHeapAtom
   , updateHeap
   , freshVar
   )
   where

import Control.Monad.State 
import Data.Map as Map hiding (map)
import Ministg.AST
import Ministg.CallStack (CallStack, push, showCallStack)
import Ministg.Pretty hiding (Style)

-- | Stack continuations.
data Continuation
   = CaseCont [Alt] CallStack -- ^ The alternatives of a case expression.
   | UpdateCont Var CallStack -- ^ A variable which points to a thunk to be updated.
   | ArgCont Atom             -- ^ A pending argument (used only by the push-enter model).
   deriving (Eq, Show)

instance Pretty Continuation where
   pretty (CaseCont alts _cs) 
      = text "case *" <+> braces (vcat (punctuate semi (map pretty alts)))
   pretty (UpdateCont var _cs)
      = text "upd *" <+> text var
   pretty (ArgCont atom) = text "arg" <+> pretty atom 

-- | The evaluation stack. 
type Stack = [Continuation]

prettyStack :: Stack -> Doc
prettyStack stack = (vcat $ map prettyCont stack)
   where
   prettyCont :: Continuation -> Doc
   prettyCont cont = text "-" <+> pretty cont

-- | The heap (mapping variables to objects).
type Heap = Map.Map Var Object
-- | State to be threaded through evaluation.

data EvalState = EvalState { state_unique :: Int, state_callStack :: CallStack }
-- | Eval monad. Combines State and IO.
type Eval a = StateT EvalState IO a
-- | The style of semantics: push-enter or eval-apply
data Style
   = PushEnter
   | EvalApply
   deriving (Eq, Show)

initState :: EvalState
initState = EvalState { state_unique = 0, state_callStack = [] }

initHeap :: Program -> Heap
initHeap = Map.fromList

initStack :: Stack
initStack = []

pushCallStack :: String -> Eval ()
pushCallStack str = do
   cs <- gets state_callStack
   modify $ \s -> s { state_callStack = push str cs }

setCallStack :: CallStack -> Eval ()
setCallStack cs = modify $ \s -> s { state_callStack = cs }

-- | Lookup a variable in a heap. If found return the corresponding
-- object, otherwise throw an error (it is a fatal error which can't
-- be recovered from).
lookupHeap :: Var -> Heap -> Object 
lookupHeap var heap = 
   case Map.lookup var heap of
      Nothing -> error $ "undefined variable: " ++ show var
      Just object -> object

-- | Convenience wrapper for lookupHeap, for atoms which happen to be variables.
lookupHeapAtom :: Atom -> Heap -> Object
lookupHeapAtom (Variable var) heap = lookupHeap var heap
lookupHeapAtom other _heap = error $ "lookupHeapAtom called with non variable " ++ show other

-- | Add a new mapping to a heap, or update an existing one.
updateHeap :: Var -> Object -> Heap -> Heap 
updateHeap = Map.insert 

-- | Generate a new unique variable. Uniqueness is guaranteed by using a
-- "$" prefix, which is not allowed in the concrete sytax of ministg programs.
freshVar :: Eval Var
freshVar = do
   u <- gets state_unique
   modify $ \s -> s { state_unique = u + 1 }
   return $ "$" ++ show u
