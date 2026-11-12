import Foundation

extension PlateKit {
    /// The header's rhythm, shared by Rao's plates: the mark's ink sits 70 px from the top and the left; every
    /// header line's ink starts at the mark's left edge (an italic first glyph overhangs by its own amount, so the
    /// page measures it); the title's ink starts 70 px under the mark's; what follows starts 54 px under the
    /// subtitle's baseline, and the page grows or shrinks to keep its foot. The mark is rao.nyc's rr-mark.png, 986 × 802
    /// with its shadow, its ink (alpha ≥ 128) at 26, 14 to 945, 761: drawn 46.2 wide at 68.8, 69.3 (`.mark` in
    /// `PlateKit`, as Braid's plates draw it), its ink is 35 px tall from 70, 70, and the caption at 145.8 keeps its gap.
    ///
    /// PIN: called, not run on load. The renderer awaits `window.__plate.settle()`, which answers the page's height
    /// once the face is loaded and everything is in place; the plates' script ran itself on `fonts.ready` and was
    /// polled for.
    static var settleScript: String {
        """
        <script>
        window.__plate = window.__plate || {};
        window.__plate.settle = () => document.fonts.ready.then(() => {
          // A page that sizes its header (an infographic fits its title) does so before the header is placed.
          if (window.__plate.before) window.__plate.before();
          const ctx = document.createElement("canvas").getContext("2d");
          const measure = (el) => {
            const cs = getComputedStyle(el), text = el.textContent.trim();
            ctx.font = `italic ${cs.fontWeight} ${cs.fontSize} Playfair`;
            const probe = document.createElement("span");
            probe.style.cssText = "display:inline-block; width:0; height:0";
            el.prepend(probe);
            const baseline = probe.getBoundingClientRect().bottom;
            probe.remove();
            return {left: parseFloat(cs.paddingLeft), top: parseFloat(cs.top), baseline,
                    ink: baseline - ctx.measureText(text).actualBoundingBoxAscent, overhang: ctx.measureText(text[0] || " ").actualBoundingBoxLeft};
          };
          const title = document.querySelector(".title"), sub = document.querySelector(".sub");
          const t = measure(title), s = measure(sub), dy = \(PlateHTML.n(PlatePalette.titleInk)) - t.ink;
          for (const [el, m] of [[title, t], [sub, s]]) {
            el.style.left = (\(PlateHTML.n(PlatePalette.ink)) - m.left + m.overhang) + "px";
            el.style.top = (m.top + dy) + "px";
          }
          const header = ".mark, .caption, .title, .sub, script, style", rest = [...document.body.children].filter((el) => !el.matches(header));
          let first = Infinity;
          for (const el of rest) {
            const r = el.getBoundingClientRect();
            if (el instanceof SVGSVGElement) {
              const b = el.getBBox();
              if (b.width || b.height) first = Math.min(first, r.top + b.y);
            } else if (r.width && r.height) first = Math.min(first, r.top);
          }
          const shift = Math.round(s.baseline + dy + \(PlateHTML.n(PlatePalette.headerGap)) - first);
          for (const el of rest) el.style.translate = `0 ${shift}px`;
          const height = parseFloat(getComputedStyle(document.body).height) + shift;
          document.documentElement.style.height = document.body.style.height = height + "px";
          document.body.dataset.height = height;
          // A page that fits its content (an infographic) ends itself once everything is in place.
          return window.__plate.after ? window.__plate.after(height) : height;
        });
        </script>
        """
    }
}
