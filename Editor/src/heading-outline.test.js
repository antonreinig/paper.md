// @vitest-environment jsdom

import { describe, expect, it } from 'vitest'
import { updateHeadingOutline } from './heading-outline'

describe('document heading outline', () => {
  it('includes only H1 headings and gives duplicate headings stable unique IDs', () => {
    document.body.innerHTML = `
      <article>
        <h1>Hello, World!</h1>
        <h2>Details</h2>
        <h1>Hello, World!</h1>
        <h1>   </h1>
      </article>
    `

    expect(updateHeadingOutline(document.querySelector('article'))).toEqual([
      { id: 'hello-world', title: 'Hello, World!' },
      { id: 'hello-world-1', title: 'Hello, World!' },
      { id: 'section', title: 'Untitled section' },
    ])
    expect(document.querySelector('h2').id).toBe('details')
  })
})
