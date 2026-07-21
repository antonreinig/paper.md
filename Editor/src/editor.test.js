import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import { TableKit } from '@tiptap/extension-table'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import { Markdown } from '@tiptap/markdown'
import { compatibilityExtensions } from './markdown-compatibility'
import { syntaxHighlightedCodeBlock } from './syntax-highlighting'
import { afterEach, describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

let editor

function makeEditor(markdown) {
  editor = new Editor({
    extensions: [
      StarterKit.configure({ link: false, codeBlock: false }),
      syntaxHighlightedCodeBlock,
      Link,
      TableKit,
      TaskList,
      TaskItem.configure({ nested: true }),
      ...compatibilityExtensions,
      Markdown.configure({ markedOptions: { gfm: true } }),
    ],
    content: markdown,
    contentType: 'markdown',
  })
  return editor
}

afterEach(() => editor?.destroy())

describe('Markdown round trip', () => {
  it('preserves headings, formatting, links, lists, quotes, and code', () => {
    const source = `# Title

Some **bold**, *italic*, and [linked](https://example.com) text.

- one
- two

> quote

\`\`\`swift
let answer = 42
\`\`\``
    const result = makeEditor(source).getMarkdown()
    expect(result).toContain('# Title')
    expect(result).toContain('**bold**')
    expect(result).toContain('[linked](https://example.com)')
    expect(result).toContain('- one')
    expect(result).toContain('> quote')
    expect(result).toContain('```swift')
  })

  it.each(['typescript', 'python', 'javascript', 'java', 'csharp', 'php', 'bash', 'cpp', 'hcl', 'go'])(
    'round-trips the language on a %s code fence',
    language => {
      const source = `\`\`\`${language}\nconst answer = 42\n\`\`\``
      expect(makeEditor(source).getMarkdown()).toContain(`\`\`\`${language}`)
    },
  )

  it('round-trips a GFM table and can add a row', () => {
    const source = `| Name | Value |
| --- | --- |
| Alpha | 1 |`
    const instance = makeEditor(source)
    expect(instance.getMarkdown()).toMatch(/\| Name\s+\| Value\s+\|/)
    instance.commands.setTextSelection(3)
    instance.commands.addRowAfter()
    expect(instance.getMarkdown().split('\n').filter(line => line.startsWith('|')).length).toBeGreaterThanOrEqual(4)
  })

  it('round-trips task lists', () => {
    const result = makeEditor('- [x] Finished\n- [ ] Open').getMarkdown()
    expect(result).toContain('- [x] Finished')
    expect(result).toContain('- [ ] Open')
  })

  it.each([
    ['front matter', '---\ntitle: Hello\ntags: [a, b]\n---\n\n# Body', 'title: Hello'],
    ['image metadata', '![Alt text](images/example.png "A title")', '![Alt text](images/example.png "A title")'],
    ['footnotes', 'Text with note[^one].\n\n[^one]: Footnote text.\n', '[^one]: Footnote text.'],
    ['math', 'Inline $x^2$ and block:\n\n$$\ny = mx + b\n$$', '$$\ny = mx + b\n$$'],
    ['highlight and superscript', 'This is ==important== and 2^10^.', '==important=='],
    ['wiki links', 'See [[Writing/Notes|my notes]].', '[[Writing/Notes|my notes]]'],
    ['HTML comments', '<!-- keep: this -->\n\nVisible', '<!-- keep: this -->'],
    ['directives', ':::note\nKeep **all** of this.\n:::\n', ':::note'],
  ])('preserves compatibility syntax: %s', (_name, source, expected) => {
    expect(makeEditor(source).getMarkdown()).toContain(expected)
  })

  it('preserves a raw HTML block including its attributes', () => {
    const source = '<div class="note" data-kind="warning">\nraw <b>HTML</b>\n</div>'
    expect(makeEditor(source).getMarkdown()).toContain(source)
  })

  it('preserves inline HTML tags and attributes', () => {
    const source = 'Use <kbd class="key">⌘K</kbd> to open links.'
    expect(makeEditor(source).getMarkdown()).toBe(source)
  })

  it('round-trips the compatibility corpus without dropping syntax', () => {
    const source = readFileSync(new URL('../test-fixtures/compatibility.md', import.meta.url), 'utf8')
    const result = makeEditor(source).getMarkdown()

    for (const fragment of [
      'title: Compatibility fixture',
      '![an image](images/example.png "Local image")',
      '| :---',
      '==highlighted==',
      '$x^2$',
      'y = mx + b',
      '[[Notes/Markdown|the wiki note]]',
      '<!-- This comment must survive. -->',
      ':::note',
      'data-purpose="round-trip"',
      '[^details]: Footnote definitions must survive.',
    ]) expect(result).toContain(fragment)
  })
})
