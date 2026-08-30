.pragma library

function resolve(path, home) {
    if (!path)
        return ""
    let p = String(path).trim()
    if (p.startsWith("file://"))
        p = decodeURIComponent(p.slice("file://".length))
    if (p.startsWith("~/") && home)
        p = home + p.slice(1)
    return p
}

function linkify(text, home) {
    if (!text)
        return ""

    return String(text).replace(/(?:file:\/\/|~\/|\/)[^\s<&]+/g, function(match, offset, full) {
        const before = full.slice(0, offset)
        if (offset > 0 && full[offset - 1] === "<")
            return match
        if (/href\s*=\s*["'][^"']*$/.test(before))
            return match
        const lastOpen = before.lastIndexOf("<a ")
        const lastClose = before.lastIndexOf("</a>")
        if (lastOpen !== -1 && lastOpen > lastClose)
            return match

        const display = match.replace(/[.,;:!?)]+$/, "")
        const trail = match.slice(display.length)
        const abs = resolve(display, home)
        if (!abs)
            return match
        return '<a href="file://' + abs + '">' + display + "</a>" + trail
    })
}
