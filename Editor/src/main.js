import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import { TableKit } from '@tiptap/extension-table'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import { Markdown } from '@tiptap/markdown'
import { compatibilityExtensions } from './markdown-compatibility'
import { createLinkPopover } from './link-popover'
import { restoreScrollPosition } from './scroll-position'
import { syntaxHighlightedCodeBlock } from './syntax-highlighting'
import { updateHeadingOutline } from './heading-outline'
import './style.css'

let applyingHostUpdate = false
let linkPopover
let lastHeadingOutline = ''

const post = (name, body = {}) => {
  const handler = window.webkit?.messageHandlers?.[name]
  if (handler) handler.postMessage(body)
}

const editor = new Editor({
  element: document.querySelector('#editor'),
  extensions: [
    StarterKit.configure({ link: false, codeBlock: false }),
    syntaxHighlightedCodeBlock,
    Link.configure({
      openOnClick: false,
      autolink: true,
      defaultProtocol: 'https',
      HTMLAttributes: { rel: 'noopener noreferrer' },
    }),
    TableKit.configure({ table: { resizable: true, lastColumnResizable: false } }),
    TaskList,
    TaskItem.configure({ nested: true }),
    ...compatibilityExtensions,
    Markdown.configure({ markedOptions: { gfm: true } }),
  ],
  content: '',
  contentType: 'markdown',
  autofocus: false,
  editorProps: {
    attributes: {
      class: 'document',
      spellcheck: 'true',
      autocapitalize: 'sentences',
      'aria-label': 'Markdown document',
    },
    handleClick(view, position, event) {
      const anchor = event.target.closest?.('a[href]')
      if (anchor) {
        event.preventDefault()
        linkPopover?.show(anchor)
        return true
      }
      return false
    },
    handleDOMEvents: {
      mouseover(view, event) {
        const anchor = event.target.closest?.('a[href]')
        if (anchor) linkPopover?.show(anchor)
        return false
      },
      mouseout(view, event) {
        const anchor = event.target.closest?.('a[href]')
        if (anchor && !anchor.contains(event.relatedTarget)) linkPopover?.hide()
        return false
      },
    },
  },
  onCreate() {
    queueMicrotask(() => {
      updateHeadingIds()
      post('ready')
      updateSelectionState()
    })
  },
  onUpdate({ editor: updatedEditor }) {
    updateHeadingIds()
    if (!applyingHostUpdate) {
      post('documentChanged', { markdown: updatedEditor.getMarkdown() })
    }
    updateSelectionState()
  },
  onSelectionUpdate: updateSelectionState,
})

linkPopover = createLinkPopover(editor, post)

function updateHeadingIds() {
  const outline = updateHeadingOutline(document.querySelector('.document'))
  const serializedOutline = JSON.stringify(outline)
  if (serializedOutline !== lastHeadingOutline) {
    lastHeadingOutline = serializedOutline
    post('headingsChanged', { headings: outline })
  }
}

function updateSelectionState() {
  if (!editor) return
  post('selectionChanged', {
    bold: editor.isActive('bold'),
    italic: editor.isActive('italic'),
    strike: editor.isActive('strike'),
    code: editor.isActive('code'),
    bulletList: editor.isActive('bulletList'),
    orderedList: editor.isActive('orderedList'),
    taskList: editor.isActive('taskList'),
    blockquote: editor.isActive('blockquote'),
    table: editor.isActive('table'),
    heading: [1, 2, 3, 4, 5, 6].find(level => editor.isActive('heading', { level })) || 0,
  })
}

const commands = {
  bold: () => editor.chain().focus().toggleBold().run(),
  italic: () => editor.chain().focus().toggleItalic().run(),
  strike: () => editor.chain().focus().toggleStrike().run(),
  code: () => editor.chain().focus().toggleCode().run(),
  link: payload => {
    if (!payload?.url) return editor.chain().focus().unsetLink().run()
    return editor.chain().focus().extendMarkRange('link').setLink({ href: payload.url }).run()
  },
  heading1: () => editor.chain().focus().toggleHeading({ level: 1 }).run(),
  heading2: () => editor.chain().focus().toggleHeading({ level: 2 }).run(),
  heading3: () => editor.chain().focus().toggleHeading({ level: 3 }).run(),
  paragraph: () => editor.chain().focus().setParagraph().run(),
  bulletList: () => editor.chain().focus().toggleBulletList().run(),
  orderedList: () => editor.chain().focus().toggleOrderedList().run(),
  taskList: () => editor.chain().focus().toggleTaskList().run(),
  blockquote: () => editor.chain().focus().toggleBlockquote().run(),
  codeBlock: () => editor.chain().focus().toggleCodeBlock().run(),
  horizontalRule: () => editor.chain().focus().setHorizontalRule().run(),
  insertTable: () => editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(),
  addRowBefore: () => editor.chain().focus().addRowBefore().run(),
  addRowAfter: () => editor.chain().focus().addRowAfter().run(),
  deleteRow: () => editor.chain().focus().deleteRow().run(),
  addColumnBefore: () => editor.chain().focus().addColumnBefore().run(),
  addColumnAfter: () => editor.chain().focus().addColumnAfter().run(),
  deleteColumn: () => editor.chain().focus().deleteColumn().run(),
  toggleHeaderRow: () => editor.chain().focus().toggleHeaderRow().run(),
  deleteTable: () => editor.chain().focus().deleteTable().run(),
  undo: () => editor.chain().focus().undo().run(),
  redo: () => editor.chain().focus().redo().run(),
  focus: () => editor.commands.focus(),
  navigateToHeading: payload => {
    const heading = payload?.id && document.getElementById(payload.id)
    if (!heading) return false
    heading.scrollIntoView({ behavior: 'smooth', block: 'start' })
    return true
  },
}

window.editorBridge = {
  loadMarkdown(markdown, scrollPosition = 0) {
    const incoming = typeof markdown === 'string' ? markdown : ''
    if (incoming !== editor.getMarkdown()) {
      applyingHostUpdate = true
      try {
        editor.commands.setContent(incoming, { contentType: 'markdown', emitUpdate: false })
        updateHeadingIds()
      } finally {
        applyingHostUpdate = false
        updateSelectionState()
      }
    }
    restoreScrollPosition(scrollPosition)
    return editor.getMarkdown()
  },
  perform(name, payload = {}) {
    return commands[name]?.(payload) ?? false
  },
  getMarkdown() {
    return editor.getMarkdown()
  },
}

// Local browser previews can provide a document without affecting the bundled file-based app.
if (location.protocol.startsWith('http')) {
  const previewParameters = new URLSearchParams(location.search)
  const previewAppearance = previewParameters.get('appearance')
  if (previewAppearance === 'light' || previewAppearance === 'dark') {
    document.documentElement.style.colorScheme = previewAppearance
  }
  const previewMarkdown = previewParameters.get('markdown')
  if (previewMarkdown) window.editorBridge.loadMarkdown(previewMarkdown)
  if (previewParameters.has('showLinkPopover')) {
    window.requestAnimationFrame(() => linkPopover.show(document.querySelector('.document a[href]')))
  }
}
