{- Main function for exporting test suites
-}

module Main where

import           RIO

import           Test.Hspec              (describe, hspec)
import           Test.Hspec.QuickCheck   (modifyMaxSuccess)

import           ParserTest              (parserSpec)
import           TestCommonMark.Blocks   (blockSpec)
import           TestCommonMark.Segments (segmentSpec)
import           TestCommonMark.Styles   (styleSpec)

main :: IO ()
main = hspec $ do
    describe "CommonMark parser" $ modifyMaxSuccess (const 200) $ do
        blockSpec
        segmentSpec
        styleSpec

    describe "Parser spec"
        parserSpec
