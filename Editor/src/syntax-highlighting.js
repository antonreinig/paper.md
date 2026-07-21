import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight'
import { common, createLowlight } from 'lowlight'

const hcl = hljs => ({
  name: 'HashiCorp Configuration Language',
  aliases: ['terraform', 'tf'],
  keywords: {
    keyword: 'for in if else dynamic content lifecycle provisioner connection',
    literal: 'true false null',
  },
  contains: [
    hljs.HASH_COMMENT_MODE,
    hljs.C_LINE_COMMENT_MODE,
    hljs.QUOTE_STRING_MODE,
    hljs.NUMBER_MODE,
    { className: 'type', begin: /\b(?:resource|data|module|variable|output|provider|terraform|locals)(?=\s+["{])/ },
    { className: 'attr', begin: /[A-Za-z_][\w-]*(?=\s*=)/ },
  ],
})

// The common bundle covers GitHub's most-used languages, including TypeScript,
// Python, JavaScript, Java, C#, PHP, Shell, C++, and Go. HCL is registered
// separately because it is also in the current top ten.
const lowlight = createLowlight(common)
lowlight.register('hcl', hcl)

export const syntaxHighlightedCodeBlock = CodeBlockLowlight.configure({
  lowlight,
  enableTabIndentation: true,
  tabSize: 2,
})
