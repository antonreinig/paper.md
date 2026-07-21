export function updateHeadingOutline(root) {
  const used = new Map()
  const outline = []
  root.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(heading => {
    const base = (heading.textContent || '')
      .trim()
      .toLowerCase()
      .replace(/[^\p{L}\p{N}\s-]/gu, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-') || 'section'
    const count = used.get(base) || 0
    used.set(base, count + 1)
    heading.id = count ? `${base}-${count}` : base
    if (heading.tagName === 'H1') {
      outline.push({ id: heading.id, title: heading.textContent.trim() || 'Untitled section' })
    }
  })
  return outline
}
