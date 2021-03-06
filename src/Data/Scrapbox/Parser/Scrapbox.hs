{-# LANGUAGE OverloadedStrings #-}

-- | Module exposes a parser for 'Scrapbox'
module Data.Scrapbox.Parser.Scrapbox
  ( runScrapboxParser,
    runSpanParser,
    runScrapTextParser,
  )
where

import Data.Char (isSpace)
import Data.Scrapbox.Exception (ScrapboxError (..))
import Data.Scrapbox.Parser.Scrapbox.ScrapText
  ( extractParagraph,
    runScrapTextParser,
    runScrapTextParserM,
  )
import Data.Scrapbox.Parser.Scrapbox.Span
  ( runSpanParser,
    runSpanParserM,
  )
import Data.Scrapbox.Types
  ( Block (..),
    CodeName (..),
    CodeSnippet (..),
    Level (..),
    Scrapbox (..),
    Start (..),
    TableContent (..),
    TableName (..),
    Url (..),
  )
import Data.Scrapbox.Utils (isURL)
import RIO hiding (many, try)
import Text.ParserCombinators.Parsec
  ( Parser,
    anyChar,
    char,
    eof,
    lookAhead,
    many,
    many1,
    manyTill,
    noneOf,
    notFollowedBy,
    oneOf,
    parse,
    satisfy,
    sepBy1,
    space,
    string,
    try,
    unexpected,
  )

--------------------------------------------------------------------------------
-- Block parser
--------------------------------------------------------------------------------

-- | Parser for 'LINEBREAK'
lineBreakParser :: Parser Block
lineBreakParser = do
  _ <- endOfLine
  return LINEBREAK

-- | Parser for @PARAGRAPH@
paragraphParser :: Parser Block
paragraphParser = do
  str <- getString
  scrapText <- runScrapTextParserM str
  return $ PARAGRAPH scrapText

-- | Parser for 'THUMBNAIL'
thumbnailParser :: Parser Block
thumbnailParser = do
  _ <- char '['
  thumbnailLink <- many1 $ satisfy (\c -> (not . isSpace) c && c /= ']')
  _ <- char ']'
  _ <- endOfLine
  if isURL thumbnailLink
    then return $ THUMBNAIL (Url $ fromString thumbnailLink)
    else unexpected "Cannot parse as Thumbnail since the content is not URI"

-- | Parser for 'BLOCK_QUOTE'
blockQuoteParser :: Parser Block
blockQuoteParser = do
  _ <- char '>'
  str <- getString
  scrapText <- runScrapTextParserM str
  return $ BLOCK_QUOTE scrapText

-- | Parser for 'HEADING'
headingParser :: Parser Block
headingParser = do
  _ <- char '['
  symbolLen <- length <$> many1 (char '*')
  _ <- space
  str <- extractParagraph
  _ <- char ']'
  _ <- endOfLine
  segments <- runSpanParserM str
  return $ HEADING (Level symbolLen) segments

-- | Parser for 'BULLET_POINT'
bulletPointParser :: Int -> Parser Block
bulletPointParser indentNum = do
  -- Look ahead and count the number of spaces
  numOfIndents <- length <$> lookAhead (try $ many1 $ oneOf indent)
  when (numOfIndents <= indentNum) $ fail "less indent"
  blocks <- many1 $ blockParser numOfIndents
  let start = numOfIndents - indentNum
  return $ BULLET_POINT (Start start) blocks

-- | Parser for 'CODE_BLOCK'
codeBlockParser :: Int -> Parser Block
codeBlockParser indentNum = do
  _ <- string "code:"
  codeName <- manyTill anyChar endOfLine
  snippet <- manyTill codeSnippetParser (notFollowedBy codeSnippetParser)
  return $ CODE_BLOCK (CodeName $ fromString codeName) (CodeSnippet snippet)
  where
    codeSnippetParser :: Parser Text
    codeSnippetParser = do
      consumeIndent indentNum
      _ <- oneOf indent
      codeLine <- manyTill anyChar endOfLine
      return $ fromString codeLine

-- | Parser to 'TABLE'
tableParser :: Int -> Parser Block
tableParser indentNum = do
  _ <- string "table:"
  tableName <- manyTill anyChar endOfLine
  -- notFollowedBy lets you consume until it fails
  tableContent <- manyTill rowParser (notFollowedBy rowParser)
  return $ TABLE (TableName $ fromString tableName) (TableContent tableContent)
  where
    rowParser :: Parser [Text]
    rowParser = do
      consumeIndent indentNum
      _ <- oneOf indent
      row <- sepBy1 (many $ noneOf "\t\n") (char '\t')
      _ <- endOfLine
      return $ map fromString row

-- | Block parser
-- Each parser must consume (or discard) indentation before parsing
blockParser ::
  -- | Number of indents
  Int ->
  Parser Block
blockParser indentNum =
  try (consumeIndent indentNum *> lineBreakParser)
    <|> try (consumeIndent indentNum *> headingParser)
    <|> try (consumeIndent indentNum *> thumbnailParser)
    <|> try (consumeIndent indentNum *> blockQuoteParser)
    <|> try (consumeIndent indentNum *> tableParser indentNum)
    <|> try (bulletPointParser indentNum)
    <|> try (consumeIndent indentNum *> codeBlockParser indentNum)
    <|> try (consumeIndent indentNum *> paragraphParser)

--------------------------------------------------------------------------------
-- Scrapbox parser
--------------------------------------------------------------------------------

-- | Parser for 'Scrapbox'
scrapboxParser :: Parser Scrapbox
scrapboxParser = Scrapbox <$> manyTill (blockParser 0) eof

-- | Run scrapbox parser on given 'String'
runScrapboxParser :: String -> Either ScrapboxError Scrapbox
runScrapboxParser toParse = either (\parseError -> Left $ ParseError parseError) return (parse scrapboxParser "Scrapbox parser" toParse)

--------------------------------------------------------------------------------
-- Helper function
--------------------------------------------------------------------------------

-- | End of line parser
endOfLine :: Parser ()
endOfLine = void (char '\n') <|> void (string "\r\n") <|> eof

-- | Consume string until end of line
getString :: Parser String
getString = manyTill anyChar (try endOfLine)

-- | Consume number of whitespaces
consumeIndent :: Int -> Parser ()
consumeIndent indentNum = replicateM_ indentNum (oneOf indent)

-- | Indent symbol
indent :: String
indent = " \t"
