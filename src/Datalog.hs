{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections       #-}
{-# LANGUAGE TypeApplications    #-}

module Datalog
  ( main
  ) where

import Control.Monad.Reader (ReaderT, runReaderT)
import Control.Monad.Reader.Class (MonadReader)
import Control.Monad.ST (ST, runST, stToIO)
import Control.Monad.Trans.Writer.CPS (runWriterT)
import Data.Foldable (foldl', foldlM)
import Data.Map.Strict (Map)
import Data.Tuple (swap)
import Data.Void (Void)
import Datalog.Cudd (CuddT, DDNode)
import Datalog.CycleEnumeration
import Datalog.Elaboration
import Datalog.Graph
import Datalog.Pretty
import Datalog.Stratification
import Datalog.Syntax

import qualified Data.Map.Strict as Map
import qualified Datalog.Cudd as Cudd

main :: IO ()
main = do
  prog <- doParse "test.datalog"

  putStrLn "Input program:"
  printProgram prog
  putStrLn ""

{-
  putStrLn "Renamed program:"
  printProgram (renameProgram prog)
  putStrLn ""

  putStrLn "Predicate Dependency Graph:"
  putStrLn $ prettyGraph $ computePredicateDependencyGraph prog
  putStrLn ""

  putStrLn "Enumerated weight cycles: "
  putStrLn $ pretty $ enumerateWeightCycles $ computePredicateDependencyGraph prog
  putStrLn ""

  putStrLn "Parity Stratification Check: "
  putStrLn $ pretty $ parityStratifyCheck prog
  putStrLn ""
-}

  let (exprs, stmts) = runTacM $ do
        (exprs0, stmts0) <- runWriterT $ renameToHead
          $ Rule (Relation (Rel 36)
              [ Left (ConstantInt 3)
              , Right (ElaborationName (Just 10))
              , Right (ElaborationName (Just 11))
              ]
            )
          $ map (, NotNegated)
            [ Relation (Rel 45)
                [ Right (ElaborationName (Just 10))
                , Right (ElaborationName (Just 11))
                ]
            ]
        pure (exprs0, stmts0)
{-
  let (stmts, exprs) = runTacM $ do
        (stmts0, exprs0) <- joinSubgoals
          $ map ((, NotNegated) . fmap ElaborationName)
            [ Relation 20 [Right (Just 9), Right (Just 6), Right (Just 7)]
            , Relation 21 [Right (Just 8), Right (Just 7), Right (Just 9)]
            , Relation 22 [Right (Just 6)]
            ]
        (stmts1, exprs1) <- joinSubgoals exprs0
        pure (stmts0 ++ stmts1, exprs1)

  let (exprs, stmts) = runTacM $ do
        (exprs0, stmts0) <- runWriterT $ selectConstants
          $ id @[Expr Int Name]
          $ map ((, NotNegated) . fmap ElaborationName)
            [ Relation 20 [Left (ConstantInt 3), Right (Just 6), Left (ConstantBitString [True,True,True,False])]
            , Relation 22 [Right (Just 6)]
            ]
        pure (exprs0, stmts0)

-}
  mapM_ (putStrLn . pretty) stmts
  mapM_ (putStrLn . prettyExpr) exprs

printProgram :: (Pretty rel, Pretty var) => Program rel var -> IO ()
printProgram prog = do
  putStrLn "Declarations:"
  mapM_ (putStrLn . pretty) (decls prog)
  putStrLn ""
  putStrLn "Types:"
  mapM_ (putStrLn . uncurry prettyType) (Map.toList (types prog))

doParse :: FilePath -> IO (Program Name Name)
doParse progFile = do
  progCode <- readFile progFile
  either fail pure (parseProgram progFile progCode)
