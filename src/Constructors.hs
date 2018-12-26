module Constructors
    ( markdown
    -- * Blocks
    , bulletList
    , blockQuote
    , bulletPoint
    , codeBlock
    , header
    , lineBreak
    , p
    , paragraph
    , table
    , thumbnail
    -- * Context
    , context
    -- * Constructors for creating 'Context' with a style
    , noStyle
    , bold
    , italic
    , strikeThrough
    , customStyle
    -- * For creating custom style
    , styleData
    -- * Segment
    , codeNotation
    , hashtag
    , link
    , text
    ) where

import           RIO   hiding (link)

import           Types

--------------------------------------------------------------------------------
-- Smart constructors
--------------------------------------------------------------------------------

markdown :: [Block] -> Markdown
markdown = Markdown

--------------------------------------------------------------------------------
-- Block
--------------------------------------------------------------------------------

blockQuote :: [Context] -> Block
blockQuote = BlockQuote . ScrapText

bulletList :: [Block] -> Block
bulletList = BulletList

codeBlock :: Text -> Text -> Block
codeBlock codeName codeSnippet = CodeBlock (CodeName codeName) (CodeSnippet codeSnippet)

paragraph :: [Context] -> Block
paragraph = Paragraph . ScrapText

p :: [Context] -> Block
p = paragraph

table :: Text -> [[Text]] -> Block
table title contents = Table (TableName title) (TableContent contents)

thumbnail :: Text -> Block
thumbnail url = Thumbnail (Url url)

header :: Int -> Content -> Block
header size contents = Header (HeaderSize size) contents

bulletPoint :: Int -> [Context] -> Block
bulletPoint size ctxs = BulletPoint (BulletSize size) (ScrapText ctxs)

lineBreak :: Block
lineBreak = LineBreak

--------------------------------------------------------------------------------
-- Context
--------------------------------------------------------------------------------

context :: Style -> Content -> Context
context = Context

noStyle :: [Segment] -> Context
noStyle segments = Context NoStyle segments

bold :: [Segment] -> Context
bold segments = Context Bold segments

italic :: [Segment] -> Context
italic segments = Context Italic segments

strikeThrough :: [Segment] -> Context
strikeThrough segments = Context StrikeThrough segments

customStyle :: StyleData -> [Segment] -> Context
customStyle sData segments = Context (CustomStyle sData) segments

--------------------------------------------------------------------------------
-- Segment
--------------------------------------------------------------------------------

text :: Text -> Segment
text = SimpleText

codeNotation :: Text -> Segment
codeNotation = CodeNotation

hashtag :: Text -> Segment
hashtag = HashTag

link :: Maybe Text -> Text -> Segment
link mName url = Link mName (Url url)

styleData :: Int -> Bool -> Bool -> Bool -> StyleData
styleData = StyleData
