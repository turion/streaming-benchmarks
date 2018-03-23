-- |
-- Module      : Benchmarks.Conduit
-- Copyright   : (c) 2018 Harendra Kumar
--
-- License     : MIT
-- Maintainer  : harendra.kumar@gmail.com

module Benchmarks.Conduit where

import Benchmarks.Common (value, maxValue)
import Control.Monad (void)
import Prelude
       (Monad, Int, (+), ($), return, even, (>), (<=),
        subtract, undefined, replicate, (<$>), (<*>))

import qualified Data.Conduit as S
import qualified Data.Conduit.Combinators as S

-------------------------------------------------------------------------------
-- Benchmark ops
-------------------------------------------------------------------------------

toNull, toList, foldl, last, scan, map, filterEven, mapM, filterAllOut,
    filterAllIn, takeOne, takeAll, takeWhileTrue, dropAll, dropWhileTrue, zip,
    concat, composeMapM, composeAllInFilters, composeAllOutFilters,
    composeMapAllInFilter
    :: Monad m
    => Int -> m ()

-------------------------------------------------------------------------------
-- Stream generation and elimination
-------------------------------------------------------------------------------

type Source m i a = S.ConduitT i a m ()
type Sink   m a r = S.ConduitT a S.Void m r
type Pipe   m a b = S.ConduitT a b m ()

source :: Monad m => Int -> Source m () Int
source n = S.enumFromTo n (n+value)

runStream :: Monad m => Sink m Int a -> Int -> m ()
runStream t n = void $ S.runConduit $ (source n) S..| t

-------------------------------------------------------------------------------
-- Elimination
-------------------------------------------------------------------------------

eliminate :: Monad m => Sink m Int a -> Int -> m ()
eliminate = runStream

toNull = eliminate $ S.mapM_ (\_ -> return ())
toList = eliminate $ S.sinkList
foldl  = eliminate $ S.foldl (+) 0
last   = eliminate $ S.last

-------------------------------------------------------------------------------
-- Transformation
-------------------------------------------------------------------------------

-- mapM_ vs sinkNull
transform :: Monad m => Pipe m Int Int -> Int -> m ()
transform t = runStream (t S..| S.mapM_ (\_ -> return ()))
--transform t = runStream (t S..| S.sinkNull)

scan          = transform $ S.scanl (+) 0
map           = transform $ S.map (+1)
mapM          = transform $ S.mapM return
filterEven    = transform $ S.filter even
filterAllOut  = transform $ S.filter (> maxValue)
filterAllIn   = transform $ S.filter (<= maxValue)
takeOne       = transform $ S.take 1
takeAll       = transform $ S.take maxValue
takeWhileTrue = transform $ S.takeWhile (<= maxValue)
dropAll       = transform $ S.drop maxValue
dropWhileTrue = transform $ S.dropWhile (<= maxValue)

-------------------------------------------------------------------------------
-- Zipping and concat
-------------------------------------------------------------------------------

zip n = S.runConduit $
        (   S.getZipSource $ (,)
        <$> S.ZipSource (source n)
        <*> S.ZipSource (source n)) S..| S.sinkNull
concat = transform (S.map (replicate 3) S..| S.concat)

-------------------------------------------------------------------------------
-- Composition
-------------------------------------------------------------------------------

compose :: Monad m => Pipe m Int Int -> Int -> m ()
compose f = transform $ (f S..| f S..| f S..| f)

composeMapM           = compose (S.mapM return)
composeAllInFilters   = compose (S.filter (<= maxValue))
composeAllOutFilters  = compose (S.filter (> maxValue))
composeMapAllInFilter = compose (S.map (subtract 1) S..| S.filter (<= maxValue))

composeScaling :: Monad m => Int -> Int -> m ()
composeScaling m n =
    case m of
        1 -> transform f n
        2 -> transform (f S..| f) n
        3 -> transform (f S..| f S..| f) n
        4 -> transform (f S..| f S..| f S..| f) n
        _ -> undefined
    where f = S.filter (<= maxValue)
