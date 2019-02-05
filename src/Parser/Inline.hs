{-| Inline parser module
-}

module Parser.Inline
    ( runInlineParser
    , runInlineParserM
    , inlineParser
    , codeNotationParser
    ) where

import           RIO                           hiding (many, try, (<|>))
import           RIO.List                      (headMaybe, initMaybe, lastMaybe,
                                                tailMaybe)

import           Data.String                   (fromString)
import qualified Data.Text                     as T
import           Network.URI                   (isURI)
import           Text.ParserCombinators.Parsec (ParseError, Parser, anyChar,
                                                between, char, eof, many, many1,
                                                manyTill, noneOf, oneOf, parse,
                                                sepBy1, space, try, unexpected,
                                                (<?>), (<|>))

import           Parser.Utils                  (lookAheadMaybe)
import           Types                         (Segment (..), Url (..))
import           Utils                         (eitherM, fromMaybeM)

--------------------------------------------------------------------------------
-- Smart contstructors
-- Do not export these. These should only be used within this module.
--------------------------------------------------------------------------------

-- | Used to create 'TEXT'
simpleText :: String -> Segment
simpleText = TEXT . fromString

-- | Used to create 'CODENOTATION'
codeNotation :: String -> Segment
codeNotation = CODE_NOTATION . fromString

-- | Used to create 'HASHTAG'
hashtag :: String -> Segment
hashtag = HASHTAG . fromString

--------------------------------------------------------------------------------
-- Parsers
--------------------------------------------------------------------------------

-- | Parser for 'CODENOTATION'
codeNotationParser :: Parser Segment
codeNotationParser = do
    content <- between (char '`') (char '`') $ many1 (noneOf "`")
    return $ codeNotation content

-- | Parser for 'HASHTAG'
hashTagParser :: Parser Segment
hashTagParser = do
    _ <- char '#'
    content <- many1 (noneOf " ")
    return $ hashtag content

-- | Parser for 'LINK'
linkParser :: Parser Segment
linkParser = do
    contents <- between (char '[') (char ']') $ sepBy1 (many1 $ noneOf "[] ") space
    if length contents <= 1
        then do
            linkContent <- getElement $ headMaybe contents
            return $ LINK Nothing (Url $ fromString linkContent)
        else do
            -- Both are viable
            --  [Haskell http://lotz84.github.io/haskell/]
            -- [http://lotz84.github.io/haskell/ Haskell]
            -- check if head or last is an url, if not the whole content is url
            linkHead  <- getElement $ headMaybe contents
            linkLast <- getElement $ lastMaybe contents
            mkLink linkHead linkLast contents
  where

    mkLink :: String -> String -> [String] -> Parser Segment
    mkLink link' link'' wholecontent
        | isURI link' = do
            nameContent <- getElement $ tailMaybe wholecontent
            return $ LINK (Just $ mkName nameContent) (Url $ fromString link')
        | isURI link'' = do
            nameContent <- getElement $ initMaybe wholecontent
            return $ LINK (Just $ mkName nameContent) (Url $ fromString link'')
        | otherwise   = return $ LINK Nothing (Url $ mkName wholecontent)

    mkName :: [String] -> Text
    mkName wholecontent = T.strip $ fromString $
      foldr (\someText acc -> someText <> " " <> acc) mempty wholecontent

    getElement :: Maybe a -> Parser a
    getElement mf = fromMaybeM (unexpected "failed to parse link content") (return mf)

-- | Parser fro 'TEXT'
simpleTextParser :: Parser Segment
simpleTextParser = simpleText <$> textParser mempty

-- Something is wrong, its causing infinite loop
-- | Parser for 'TEXT'
textParser :: String -> Parser String
textParser content = do
    someChar <- lookAheadMaybe anyChar
    case someChar of

        -- Nothing is ahead of it, the work is done
        Nothing  -> return content

        -- Could be link so try to parse it
        Just '[' -> checkWith linkParser content

        -- Could be code notation so try to parse it
        Just '`' -> checkWith codeNotationParser content

        -- Could be hashtag, so try to parse it
        Just '#' -> checkWith hashTagParser content

        -- For everything else, parse until it hits the syntax symbol
        Just _   -> do
            text <- many1 $ noneOf syntaxSymbol
            textParser text
  where
    -- Check if the ahead content can be parsed by the given parser,
    -- if not, consume them as simpletext until next symbol
    checkWith :: Parser a -> String -> Parser String
    checkWith parser content' = do
        mResult <- lookAheadMaybe parser
        if isJust mResult
            then return content
            else do
                someSymbol <- oneOf syntaxSymbol
                rest       <- many $ noneOf syntaxSymbol
                textParser $ content' <> [someSymbol] <> rest

    syntaxSymbol :: String
    syntaxSymbol = "[`#"

-- | Parse inline text into list of 'Segment'
segmentParser :: Parser Segment
segmentParser =
        try codeNotationParser
    <|> try linkParser
    <|> try hashTagParser
    <|> try simpleTextParser
    <?> "failed to parse segment"

-- | Parser for inline text
inlineParser :: Parser [Segment]
inlineParser = manyTill segmentParser eof-- May want to switch over to many1 to make it fail

-- | Run inline text parser on given 'String'
--
-- @
-- > runInlineParser "hello [hello yahoo link http://www.yahoo.co.jp] [hello] [] `weird code [weird url #someHashtag"
-- Right
--     [ SimpleText "hello "
--     , Link ( Just "hello yahoo link" ) ( Url "http://www.yahoo.co.jp" )
--     , SimpleText " "
--     , Link Nothing ( Url "hello" )
--     , SimpleText " [] `weird code [weird url "
--     , HashTag "someHashtag"
--     ]
-- @
runInlineParser :: String -> Either ParseError [Segment]
runInlineParser = parse inlineParser "Inline text parser"

-- | Monadic version of 'runInlineParser'
runInlineParserM :: String -> Parser [Segment]
runInlineParserM content =
    eitherM
        (\_ -> unexpected "Failed to parse inline text")
        return
        (return $ runInlineParser content)
