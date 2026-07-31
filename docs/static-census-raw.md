# Combat static appearance census — raw

Source: `/Users/jamesto/Coding/roguecardv2-benchmark/src/styles.css` at `6e06911` (verified).  
Date: 2026-07-31. Scope: static appearance declarations for the combat surface only. Animation, transition and keyframe declarations are excluded; interaction pseudo-class rules are listed separately. Line numbers are the physical declaration lines in the frozen stylesheet.

State of the PORT column: a mechanical evidence pass has run — 459 rows are
`n/a (structural)` (CSS layout plumbing the scene tree expresses instead), and
the rest carry either a `file:line` whose quoted code contains the row's own
hex or pixel value, or `not found`. Every evidence line that failed that
containment test was wiped back to `not found` rather than left to mislead
(the pass's number-coincidence matches were worthless — a 0.8 audio crossfade
is not a drop-shadow). VERDICT stays `—` throughout: judging a located value
against the running screen is per-row work the mechanical pass cannot do, and
rows where the evidence cites a DIFFERENT surface's constant (the same hex can
live on two widgets) still need that read. The verdict pass is the standing
follow-up; the reliable yield so far is the colour table — every named chrome
hex that was searched (#ffb9b9, #ffab7a, #ff9bea, #b52a3e, #05070e among them)
was found in the port with the hex quoted beside its Color literal.

Method: full-file rule walk with comments removed while preserving newlines; each in-scope selector body was scanned for the requested static property families. Media/container-rule context is retained in selectors. No markup was read, so no selector is labelled DEAD.

## Enemy chrome

| styles.css line | selector | property | value | port | verdict |
| ---: | --- | --- | --- | --- | --- |
| 103 | .enemy.doomed .cracks | filter | drop-shadow(0 0 7px rgba(255, 255, 255, 0.95)) | not found | — |
| 104 | .enemy.doomed .cracks path | opacity | 1 |  not found | — |
| 684 | .combat-screen .cast-shadow-layer | position | absolute | n/a (structural) | — |
| 684 | .combat-screen .cast-shadow-layer | inset | 0 | n/a (structural) | — |
| 684 | .combat-screen .cast-shadow-layer | z-index | 5 | n/a (structural) | — |
| 732 | .enemy-zone | position | absolute | n/a (structural) | — |
| 732 | .enemy-zone | inset | 0 | n/a (structural) | — |
| 733 | .player-zone, .enemy | position | absolute | n/a (structural) | — |
| 735 | .hero-wrap | position | relative | n/a (structural) | — |
| 735 | .hero-wrap | width | 100% | n/a (structural) | — |
| 735 | .hero-wrap | height | 100% | n/a (structural) | — |
| 736 | .hero-sprite, .enemy-sprite | position | relative | n/a (structural) | — |
| 736 | .hero-sprite, .enemy-sprite | width | 100% | n/a (structural) | — |
| 736 | .hero-sprite, .enemy-sprite | height | 100% | n/a (structural) | — |
| 736 | .hero-sprite, .enemy-sprite | z-index | 1 | n/a (structural) | — |
| 737 | .hero-wrap svg | width | 100% | n/a (structural) | — |
| 737 | .hero-wrap svg | height | 100% | n/a (structural) | — |
| 744 | .cplate | position | absolute | n/a (structural) | — |
| 744 | .cplate | top | 100% | n/a (structural) | — |
| 744 | .cplate | left | 50% | n/a (structural) | — |
| 745 | .cplate | translate | calc(-50% + var(--chrome-dx, 0px)) var(--chrome-dy, 0px) | n/a (structural) | — |
| 746 | .cplate | gap | 6px | n/a (structural) | — |
| 746 | .cplate | z-index | 3 | n/a (structural) | — |
| 747 | .cplate | padding-top | 6px | n/a (structural) | — |
| 747 | .cplate | width | max-content | n/a (structural) | — |
| 747 | .cplate | max-width | 260px | n/a (structural) | — |
| 750 | .top-chrome | position | absolute | n/a (structural) | — |
| 750 | .top-chrome | bottom | calc(100% + 8px) | n/a (structural) | — |
| 750 | .top-chrome | left | 50% | n/a (structural) | — |
| 751 | .top-chrome | translate | calc(-50% + var(--chrome-dx, 0px)) var(--chrome-dy, 0px) | n/a (structural) | — |
| 751 | .top-chrome | z-index | 3 | n/a (structural) | — |
| 752 | .top-chrome | gap | 4px | n/a (structural) | — |
| 755 | .player-zone .top-chrome | bottom | calc(100% + 2px) | n/a (structural) | — |
| 756 | .top-chrome .intent | position | static | n/a (structural) | — |
| 756 | .top-chrome .intent | translate | none | n/a (structural) | — |
| 758 | .enemy-art | position | relative | n/a (structural) | — |
| 759 | .enemy-sprite | position | relative | n/a (structural) | — |
| 759 | .enemy-sprite | width | 100% | n/a (structural) | — |
| 759 | .enemy-sprite | height | 100% | n/a (structural) | — |
| 759 | .enemy-sprite | z-index | 1 | n/a (structural) | — |
| 761 | .enemy[data-variant-id] .enemy-sprite | filter | hue-rotate(var(--variant-hue, 0deg)) saturate(var(--variant-sat, 1)) brightness(var(--variant-bright, 1)) |  not found | — |
| 766 | .enemy-art > .enemy-sprite > svg.cracks-overlay, .enemy-art > svg.enemy-svg | width | 100% | n/a (structural) | — |
| 766 | .enemy-art > .enemy-sprite > svg.cracks-overlay, .enemy-art > svg.enemy-svg | height | 100% | n/a (structural) | — |
| 770 | .cast-shadow | position | absolute | n/a (structural) | — |
| 772 | .cast-shadow | transform | translate(var(--sh-x, 0), var(--sh-y, 0)) scale(var(--sh-sx, 1), var(--sh-sy, 0.24)) skewX(var(--sh-skew, 0deg)) | n/a (structural) | — |
| 773 | .cast-shadow | opacity | var(--sh-o, 0.62) | presentation/combat/card_shine.gdshader:27:	float s = smoothstep(0.62, 0.92, u); | — |
| 773 | .cast-shadow | filter | blur(var(--sh-blur, 1.5px)) |  not found | — |
| 773 | .cast-shadow | mix-blend-mode | multiply | not found | — |
| 776 | .cast-shadow img, .cast-shadow svg | position | absolute | n/a (structural) | — |
| 776 | .cast-shadow img, .cast-shadow svg | inset | 0 | n/a (structural) | — |
| 776 | .cast-shadow img, .cast-shadow svg | width | 100% | n/a (structural) | — |
| 776 | .cast-shadow img, .cast-shadow svg | height | 100% | n/a (structural) | — |
| 777 | .cast-shadow img, .cast-shadow svg | filter | brightness(0) contrast(1.2) | not found | — |
| 780 | .cast-shadow-blob | inset | auto 8% -2px | n/a (structural) | — |
| 780 | .cast-shadow-blob | top | auto | n/a (structural) | — |
| 780 | .cast-shadow-blob | height | 14px | n/a (structural) | — |
| 780 | .cast-shadow-blob | filter | none | not found | — |
| 780 | .cast-shadow-blob | mix-blend-mode | normal | not found | — |
| 781 | .cast-shadow-blob | background | radial-gradient(ellipse 78% 100% at 50% 50%, rgba(0, 0, 0, 0.5), transparent 72%) | presentation/combat/card_surface.gd:277:		"pearl": 0.024, "pearl_scale": 78.0, | — |
| 786 | .hero-sprite > .raster-art, .enemy-sprite > .raster-art | filter | url(#alpha-erode) | not found | — |
| 794 | .enemy .name | font-family | 'Cinzel', serif | not found | — |
| 794 | .enemy .name | font-size | 13.5px |  not found | — |
| 794 | .enemy .name | letter-spacing | 0.1em |  not found | — |
| 794 | .enemy .name | color | var(--text-dim) | not found | — |
| 795 | .enemy .name | text-shadow | -1px -1px 0 rgba(0, 0, 0, 0.95), 1px -1px 0 rgba(0, 0, 0, 0.95), -1px 1px 0 rgba(0, 0, 0, 0.95), 1px 1px 0 rgba(0, 0, 0, 0.95), 0 0 4px rgba(0, 0, 0, 0.9), 0 2px 8px rgba(0, 0, 0, 0.85) | not found | — |
| 801 | .enemy.elite-e .name | color | #ffab7a | presentation/combat/enemy_view.gd:560:const NAME_ELITE: Color = Color(1.0, 0.67058825, 0.47843137)       # #ffab7a | — |
| 802 | .enemy.elite-e .name | text-shadow | -1px -1px 0 rgba(0, 0, 0, 0.95), 1px -1px 0 rgba(0, 0, 0, 0.95), -1px 1px 0 rgba(0, 0, 0, 0.95), 1px 1px 0 rgba(0, 0, 0, 0.95), 0 0 4px rgba(0, 0, 0, 0.9), 0 0 8px rgba(255, 120, 71, 0.5) | not found | — |
| 808 | .enemy.boss-e .name | color | #ff9bea | presentation/combat/enemy_view.gd:561:const NAME_BOSS: Color = Color(1.0, 0.60784316, 0.91764706)        # #ff9bea | — |
| 808 | .enemy.boss-e .name | font-size | 15px |  not found | — |
| 809 | .enemy.boss-e .name | text-shadow | -1px -1px 0 rgba(0, 0, 0, 0.95), 1px -1px 0 rgba(0, 0, 0, 0.95), -1px 1px 0 rgba(0, 0, 0, 0.95), 1px 1px 0 rgba(0, 0, 0, 0.95), 0 0 4px rgba(0, 0, 0, 0.9), 0 0 10px rgba(255, 79, 216, 0.6) | not found | — |
| 962 | .enemy.marked .cracks | filter | drop-shadow(0 0 6px rgba(255, 214, 190, 0.9)) | not found | — |
| 963 | .enemy.marked .cracks path | opacity | 1 |  not found | — |
| 966 | .enemy-sprite | z-index | 1 | n/a (structural) | — |
| 967 | .cracks-overlay | position | absolute | n/a (structural) | — |
| 967 | .cracks-overlay | inset | 0 | n/a (structural) | — |
| 967 | .cracks-overlay | z-index | 2 | n/a (structural) | — |
| 968 | .cracks | filter | drop-shadow(0 0 1.1px rgba(159, 212, 255, 0.5)) | not found | — |
| 969 | .enemy.lowhp .enemy-art svg.cracks-overlay | transform | none | n/a (structural) | — |
| 970 | .hero-wrap.lowhp svg.cracks-overlay | transform | none | n/a (structural) | — |
| 973 | .vessel-fire | position | absolute | n/a (structural) | — |
| 973 | .vessel-fire | inset | 14% | n/a (structural) | — |
| 973 | .vessel-fire | z-index | 1 | n/a (structural) | — |
| 973 | .vessel-fire | border-radius | 50% |  not found | — |
| 973 | .vessel-fire | opacity | 0 | not found | — |
| 973 | .vessel-fire | mix-blend-mode | screen | not found | — |
| 973 | .vessel-fire | filter | blur(3px) | not found | — |
| 973 | .vessel-fire | background | radial-gradient(circle at 50% 52%, rgba(255, 231, 165, 0.98) 0%, rgba(255, 150, 60, 0.55) 46%, transparent 72%) |  not found | — |
| 976 | .enemy.igniting .cracks path | opacity | 1 |  not found | — |
| 1220 | .enemy.affixed .enemy-art | filter | drop-shadow(0 0 14px color-mix(in srgb, var(--affix-tone) 55%, transparent)) | not found | — |
| 1222 | .enemy.affixed .name .affix-name | letter-spacing | 0.1em |  not found | — |
| 1223 | .enemy.affixed .name .affix-name | text-shadow | -1px -1px 0 rgba(0, 0, 0, 0.95), 1px -1px 0 rgba(0, 0, 0, 0.95), -1px 1px 0 rgba(0, 0, 0, 0.95), 1px 1px 0 rgba(0, 0, 0, 0.95), 0 0 4px rgba(0, 0, 0, 0.9), 0 0 10px currentColor | not found | — |
| 1245 | .aim-ring | position | absolute | n/a (structural) | — |
| 1245 | .aim-ring | inset | 0 | n/a (structural) | — |
| 1245 | .aim-ring | width | 100% | n/a (structural) | — |
| 1245 | .aim-ring | height | 100% | n/a (structural) | — |
| 1245 | .aim-ring | margin | 0 | n/a (structural) | — |
| 1246 | .aim-ring | z-index | 5 | n/a (structural) | — |
| 1246 | .aim-ring | opacity | 0 | not found | — |
| 1249 | .aim-ring image | width | 100% | n/a (structural) | — |
| 1249 | .aim-ring image | height | 100% | n/a (structural) | — |
| 1251 | .enemy.aim-target:not(.aim-mesh) .aim-ring, .hero-wrap.aim-target:not(.aim-mesh) .aim-ring | opacity | 1 |  not found | — |
| 1327 | .hero-wrap.warded::before, .enemy-art.warded::before | position | absolute | n/a (structural) | — |
| 1327 | .hero-wrap.warded::before, .enemy-art.warded::before | inset | -6% | n/a (structural) | — |
| 1327 | .hero-wrap.warded::before, .enemy-art.warded::before | border-radius | 50% |  not found | — |
| 1327 | .hero-wrap.warded::before, .enemy-art.warded::before | z-index | 3 | n/a (structural) | — |
| 1328 | .hero-wrap.warded::before, .enemy-art.warded::before | border | 1.5px solid rgba(150, 200, 255, 0.45) |  not found | — |
| 1329 | .hero-wrap.warded::before, .enemy-art.warded::before | box-shadow | 0 0 18px rgba(130, 185, 255, 0.35), inset 0 0 28px rgba(130, 185, 255, 0.18) | not found | — |
| 1393 | .end-turn.enemy-phase | opacity | 0.45 |  not found | — |
| 1607 | .enemy.lowhp .enemy-art svg | transform | rotate(2.4deg) translateY(4px) scale(0.985) | n/a (structural) | — |
| 1608 | .hero-wrap.lowhp svg | transform | rotate(-2deg) translateY(4px) | n/a (structural) | — |
| 2124 | @container stage (max-width: 740px) → .enemy .hpbar-wrap | width | 80px | n/a (structural) | — |
| 2124 | @container stage (max-width: 740px) → .enemy .hpbar-wrap | gap | 2px | n/a (structural) | — |
| 2125 | @container stage (max-width: 740px) → .enemy .hp-label | min-width | 36px | n/a (structural) | — |
| 2125 | @container stage (max-width: 740px) → .enemy .hp-label | font-size | 10px |  not found | — |
| 2126 | @container stage (max-width: 740px) → .enemy .block-chip | min-width | 0 | n/a (structural) | — |
| 2126 | @container stage (max-width: 740px) → .enemy .block-chip | height | 22px | n/a (structural) | — |
| 2126 | @container stage (max-width: 740px) → .enemy .block-chip | padding | 0 2px | n/a (structural) | — |
| 2126 | @container stage (max-width: 740px) → .enemy .block-chip | gap | 1px | n/a (structural) | — |
| 2126 | @container stage (max-width: 740px) → .enemy .block-chip | font-size | 11px |  not found | — |
| 2127 | @container stage (max-width: 740px) → .enemy .block-chip .ic | margin | 0 -4px 0 0 | n/a (structural) | — |
| 2128 | @container stage (max-width: 740px) → .enemy .block-chip .ic .ui-icon, .enemy .block-chip .ic .gicon | width | 22px | n/a (structural) | — |
| 2128 | @container stage (max-width: 740px) → .enemy .block-chip .ic .ui-icon, .enemy .block-chip .ic .gicon | height | 22px | n/a (structural) | — |
| 2130 | @container stage (max-width: 740px) → .enemy .name | font-size | 10.5px |  not found | — |
| 2130 | @container stage (max-width: 740px) → .enemy .name | letter-spacing | 0.06em |  not found | — |
| 2131 | @container stage (max-width: 740px) → .enemy.boss-e .name | font-size | 12px |  not found | — |
| 2204 | @container stage (max-height: 480px) and (min-width: 500px) → .enemy .name | font-size | 10.5px |  not found | — |

## HP bar

| styles.css line | selector | property | value | port | verdict |
| ---: | --- | --- | --- | --- | --- |
| 814 | .hpbar-wrap | gap | 6px | n/a (structural) | — |
| 814 | .hpbar-wrap | width | 150px | n/a (structural) | — |
| 815 | .hp-vial | position | relative | n/a (structural) | — |
| 815 | .hp-vial | min-height | 14px | n/a (structural) | — |
| 818 | .hp-vial-frame | position | absolute | n/a (structural) | — |
| 818 | .hp-vial-frame | left | -5px | n/a (structural) | — |
| 818 | .hp-vial-frame | right | -5px | n/a (structural) | — |
| 818 | .hp-vial-frame | top | 50% | n/a (structural) | — |
| 819 | .hp-vial-frame | width | calc(100% + 10px) | n/a (structural) | — |
| 819 | .hp-vial-frame | height | 22px | n/a (structural) | — |
| 820 | .hp-vial-frame | max-width | none | n/a (structural) | — |
| 820 | .hp-vial-frame | transform | translateY(-50%) | n/a (structural) | — |
| 821 | .hp-vial-frame | z-index | 2 | n/a (structural) | — |
| 823 | .hp-vial .hpbar | position | relative | n/a (structural) | — |
| 823 | .hp-vial .hpbar | z-index | 1 | n/a (structural) | — |
| 823 | .hp-vial .hpbar | width | 100% | n/a (structural) | — |
| 826 | .hp-vial:has(.hp-vial-frame) .hpbar | border-color | transparent | not found | — |
| 827 | .hp-vial:has(.hp-vial-frame) .hpbar | box-shadow | none | not found | — |
| 828 | .hp-vial:has(.hp-vial-frame) .hpbar | background | rgba(0, 0, 0, 0.35) | not found | — |
| 829 | .hp-vial:has(.hp-vial-frame) .hpbar | margin | 0 4px | n/a (structural) | — |
| 830 | .hp-vial:has(.hp-vial-frame) .hpbar | height | 9px | n/a (structural) | — |
| 831 | .hp-vial:has(.hp-vial-frame) .hpbar | border-radius | 2px | not found | — |
| 833 | .hpbar | height | 9px | n/a (structural) | — |
| 833 | .hpbar | border-radius | 5px | not found | — |
| 833 | .hpbar | background | rgba(0, 0, 0, 0.55) | not found | — |
| 833 | .hpbar | border | 1px solid var(--lead) | not found | — |
| 833 | .hpbar | box-shadow | inset 0 0 0 1px rgba(255, 255, 255, 0.06) | not found | — |
| 833 | .hpbar | position | relative | n/a (structural) | — |
| 834 | .hpbar > .fill | height | 100% | n/a (structural) | — |
| 834 | .hpbar > .fill | background | linear-gradient(90deg, #b52a3e, #ff6a5e) | presentation/combat/enemy_view.gd:75:const RAIL_FROM: Color = Color(0.70980394, 0.16470589, 0.24313726)   # #b52a3e | — |
| 834 | .hpbar > .fill | border-radius | 5px | not found | — |
| 835 | .hpbar > .ghost | position | absolute | n/a (structural) | — |
| 835 | .hpbar > .ghost | inset | 0 | n/a (structural) | — |
| 835 | .hpbar > .ghost | height | 100% | n/a (structural) | — |
| 835 | .hpbar > .ghost | background | rgba(255, 230, 160, 0.55) | presentation/combat/aim_arc.gd:14:## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with | — |
| 835 | .hpbar > .ghost | border-radius | 5px | not found | — |
| 835 | .hpbar > .ghost | z-index | -0 | n/a (structural) | — |
| 835 | .hpbar > .ghost | mix-blend-mode | screen | not found | — |
| 836 | .hp-label | font-size | 12px |  not found | — |
| 836 | .hp-label | font-weight | 700 |  not found | — |
| 836 | .hp-label | color | #ffb9b9 | presentation/combat/enemy_view.gd:81:const HP_LABEL_TINT: Color = Color(1.0, 0.7254902, 0.7254902)        # #ffb9b9 | — |
| 836 | .hp-label | min-width | 52px | n/a (structural) | — |
| 956 | .hpbar > .pv | position | absolute | n/a (structural) | — |
| 956 | .hpbar > .pv | top | 0 | n/a (structural) | — |
| 956 | .hpbar > .pv | bottom | 0 | n/a (structural) | — |
| 956 | .hpbar > .pv | border-radius | 5px | not found | — |
| 957 | .hpbar > .pv | background | rgba(255, 240, 216, 0.9) | presentation/combat/aim_arc.gd:14:## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with | — |
| 957 | .hpbar > .pv | mix-blend-mode | screen | not found | — |
| 957 | .hpbar > .pv | opacity | 0 | not found | — |
| 959 | .hpbar > .pv.show | opacity | 1 |  not found | — |
| 2123 | @container stage (max-width: 740px) → .hpbar-wrap | width | 118px | n/a (structural) | — |
| 2203 | @container stage (max-height: 480px) and (min-width: 500px) → .player-zone .hpbar-wrap, .hpbar-wrap | width | 118px | n/a (structural) | — |

## Chips and pips

| styles.css line | selector | property | value | port | verdict |
| ---: | --- | --- | --- | --- | --- |
| 839 | .block-chip | gap | 3px | n/a (structural) | — |
| 839 | .block-chip | min-width | 34px | n/a (structural) | — |
| 839 | .block-chip | height | 26px | n/a (structural) | — |
| 840 | .block-chip | padding | 0 7px | n/a (structural) | — |
| 840 | .block-chip | border-radius | 13px | not found | — |
| 841 | .block-chip | background | linear-gradient(180deg, #1c3b55, #0e2033) | not found | — |
| 841 | .block-chip | border | 1.5px solid var(--blk) |  not found | — |
| 841 | .block-chip | color | #cdeeff | presentation/combat/floaters.gd:31:	"blockf": Color(0.8039216, 0.93333334, 1.0),       # #cdeeff | — |
| 842 | .block-chip | font-weight | 700 |  not found | — |
| 842 | .block-chip | font-size | 13.5px |  not found | — |
| 843 | .block-chip | box-shadow | 0 0 10px rgba(127, 212, 255, 0.35) | not found | — |
| 843 | .block-chip | text-shadow | 0 0 6px rgba(127, 212, 255, 0.8) | not found | — |
| 846 | .block-chip .ic | position | relative | n/a (structural) | — |
| 846 | .block-chip .ic | z-index | 1 | n/a (structural) | — |
| 847 | .block-chip .ic | margin | -6px 2px -6px -14px | n/a (structural) | — |
| 847 | .block-chip .ic | color | var(--blk) | not found | — |
| 850 | .block-chip .ic .ui-icon, .block-chip .ic .gicon | width | 34px | n/a (structural) | — |
| 850 | .block-chip .ic .ui-icon, .block-chip .ic .gicon | height | 34px | n/a (structural) | — |
| 852 | .block-chip .ic .ui-icon, .block-chip .ic .gicon | filter | drop-shadow(0 0 0.75px currentColor) drop-shadow(0 0 1.25px currentColor) drop-shadow(0 0 2px color-mix(in srgb, currentColor 80%, transparent)) | not found | — |
| 861 | .status-row | gap | 6px | n/a (structural) | — |
| 861 | .status-row | min-height | 32px | n/a (structural) | — |
| 862 | .status-row | max-width | 240px | n/a (structural) | — |
| 868 | .schip | position | relative | n/a (structural) | — |
| 868 | .schip | width | 32px | n/a (structural) | — |
| 868 | .schip | height | 32px | n/a (structural) | — |
| 868 | .schip | padding | 0 | n/a (structural) | — |
| 869 | .schip | background | none | not found | — |
| 869 | .schip | border | none | not found | — |
| 869 | .schip | font-weight | 800 |  not found | — |
| 872 | .schip-art | width | 32px | n/a (structural) | — |
| 872 | .schip-art | height | 32px | n/a (structural) | — |
| 874 | .schip-art | filter | url(#status-outline) | not found | — |
| 877 | .schip svg | width | 28px | n/a (structural) | — |
| 877 | .schip svg | height | 28px | n/a (structural) | — |
| 878 | .schip svg | filter | url(#status-outline) | not found | — |
| 881 | .schip .n | position | absolute | n/a (structural) | — |
| 881 | .schip .n | right | -2px | n/a (structural) | — |
| 881 | .schip .n | bottom | -4px | n/a (structural) | — |
| 881 | .schip .n | padding | 0 | n/a (structural) | — |
| 882 | .schip .n | font-size | 12px |  not found | — |
| 882 | .schip .n | font-weight | 800 |  not found | — |
| 883 | .schip .n | color | #fff | not found | — |
| 884 | .schip .n | text-shadow | -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000, 0 0 3px #000, 0 1px 4px rgba(0, 0, 0, 0.9) | not found | — |
| 888 | .schip.buff | color | #9fd8ff | not found | — |
| 889 | .schip.debuff | color | #ffb08d | not found | — |
| 987 | .facet-row | gap | 5px | n/a (structural) | — |
| 987 | .facet-row | min-height | 18px | n/a (structural) | — |
| 987 | .facet-row | margin-top | 5px | n/a (structural) | — |
| 989 | .facet-row .pip | width | 10px | n/a (structural) | — |
| 989 | .facet-row .pip | height | 10px | n/a (structural) | — |
| 989 | .facet-row .pip | transform | rotate(45deg) | n/a (structural) | — |
| 989 | .facet-row .pip | border-radius | 1.5px |  not found | — |
| 991 | .facet-row .pip | background | radial-gradient(circle at 40% 35%, #fff, #bfe0ff 55%, #5a86c8 95%) | presentation/combat/card_edge.gdshader:84:		vec3 dull = mix(t, vec3(dot(t, vec3(0.333))), 0.40); | — |
| 992 | .facet-row .pip | border | 1.5px solid #dfeeff |  not found | — |
| 993 | .facet-row .pip | box-shadow | 0 1px 3px rgba(0, 0, 0, 0.95), 0 0 8px rgba(160, 205, 255, 0.75), inset 0 0 0 1px rgba(255, 255, 255, 0.22) | not found | — |
| 1000 | .facet-row .pip .facet-img | width | 16px | n/a (structural) | — |
| 1000 | .facet-row .pip .facet-img | height | 16px | n/a (structural) | — |
| 1002 | .facet-row .pip .facet-img | filter | drop-shadow(0 1px 2px rgba(0, 0, 0, 1)) brightness(2.55) contrast(1.35) saturate(1.15) | not found | — |
| 1007 | .facet-row .pip:has(.facet-img) | background | transparent | not found | — |
| 1007 | .facet-row .pip:has(.facet-img) | border-color | transparent | not found | — |
| 1007 | .facet-row .pip:has(.facet-img) | box-shadow | none | not found | — |
| 1008 | .facet-row .pip:has(.facet-img) | width | 16px | n/a (structural) | — |
| 1008 | .facet-row .pip:has(.facet-img) | height | 16px | n/a (structural) | — |
| 1008 | .facet-row .pip:has(.facet-img) | transform | none | n/a (structural) | — |
| 1008 | .facet-row .pip:has(.facet-img) | border-radius | 0 | not found | — |
| 1012 | .facet-row .pip.filled | background | rgba(90, 40, 45, 0.72) |  not found | — |
| 1013 | .facet-row .pip.filled | border-color | #ff6a5c | not found | — |
| 1014 | .facet-row .pip.filled | box-shadow | 0 0 6px rgba(255, 70, 60, 0.85), 0 1px 2px rgba(0, 0, 0, 0.95), inset 0 0 0 1px rgba(255, 140, 120, 0.35) | not found | — |
| 1020 | .facet-row .pip.filled:has(.facet-img) | background | transparent | not found | — |
| 1020 | .facet-row .pip.filled:has(.facet-img) | border-color | transparent | not found | — |
| 1020 | .facet-row .pip.filled:has(.facet-img) | box-shadow | none | not found | — |
| 1021 | .facet-row .pip.filled:has(.facet-img) | filter | none | not found | — |
| 1024 | .facet-row .pip.filled .facet-img | filter | drop-shadow(0 0 2px rgba(255, 70, 60, 1)) drop-shadow(0 0 4px rgba(220, 35, 35, 0.9)) drop-shadow(0 1px 2px rgba(0, 0, 0, 0.95)) brightness(1.25) contrast(1.2) | not found | — |
| 1031 | .facet-row .pip.willchip | border-color | #ff8a7a | not found | — |
| 1031 | .facet-row .pip.willchip | background | rgba(160, 50, 45, 0.55) |  not found | — |
| 1032 | .facet-row .pip.willchip | box-shadow | 0 0 6px rgba(255, 90, 70, 0.65), 0 1px 2px rgba(0, 0, 0, 0.9) | not found | — |
| 1036 | .facet-row .pip.willchip:has(.facet-img) | background | transparent | not found | — |
| 1036 | .facet-row .pip.willchip:has(.facet-img) | border-color | transparent | not found | — |
| 1036 | .facet-row .pip.willchip:has(.facet-img) | box-shadow | none | not found | — |
| 1038 | .facet-row .pip.willchip:has(.facet-img) | filter | none | not found | — |
| 1041 | .facet-row .pip.willchip .facet-img | filter | drop-shadow(0 0 3px rgba(255, 110, 90, 0.95)) drop-shadow(0 0 5px rgba(220, 50, 40, 0.7)) drop-shadow(0 1px 2px rgba(0, 0, 0, 0.95)) brightness(1.45) contrast(1.2) | not found | — |
| 1047 | .facet-row.willshatter .pip | border-color | #ffd8a0 | presentation/combat/combat_screen.gd:242:const WARM_GOLD: Color = Color(1.0, 0.84705883, 0.627451)       # #ffd8a0 | — |
| 1047 | .facet-row.willshatter .pip | box-shadow | 0 0 6px rgba(255, 200, 130, 0.5) | not found | — |
| 1049 | .facet-row.willshatter .pip:has(.facet-img) | border-color | transparent | not found | — |
| 1049 | .facet-row.willshatter .pip:has(.facet-img) | box-shadow | none | not found | — |
| 1050 | .facet-row.willshatter .pip:has(.facet-img) | filter | none | not found | — |
| 1053 | .facet-row.willshatter .pip .facet-img | filter | drop-shadow(0 0 4px rgba(255, 216, 160, 1)) drop-shadow(0 1px 2px rgba(0, 0, 0, 0.95)) brightness(1.65) contrast(1.2) | not found | — |
| 1059 | .facet-row .pipnum | font-family | 'Cinzel', serif | not found | — |
| 1059 | .facet-row .pipnum | font-size | 12.5px |  not found | — |
| 1059 | .facet-row .pipnum | font-weight | 800 |  not found | — |
| 1059 | .facet-row .pipnum | color | #bfe0ff | not found | — |
| 1059 | .facet-row .pipnum | gap | 3px | n/a (structural) | — |
| 1060 | .facet-row .pipnum i | color | #ffe9ac | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 2129 | @container stage (max-width: 740px) → .status-row | max-width | 34cqw | n/a (structural) | — |
| 2146 | @container stage (max-width: 740px) → .facet-row | gap | 4px | n/a (structural) | — |
| 2146 | @container stage (max-width: 740px) → .facet-row | margin-top | 3px | n/a (structural) | — |
| 2147 | @container stage (max-width: 740px) → .facet-row .pip | width | 8px | n/a (structural) | — |
| 2147 | @container stage (max-width: 740px) → .facet-row .pip | height | 8px | n/a (structural) | — |
| 2148 | @container stage (max-width: 740px) → .facet-row .pip:has(.facet-img), .facet-row .pip .facet-img | width | 14px | n/a (structural) | — |
| 2148 | @container stage (max-width: 740px) → .facet-row .pip:has(.facet-img), .facet-row .pip .facet-img | height | 14px | n/a (structural) | — |
| 2218 | @container stage (max-height: 480px) and (min-width: 500px) → .facet-row | gap | 3px | n/a (structural) | — |
| 2218 | @container stage (max-height: 480px) and (min-width: 500px) → .facet-row | margin-top | 2px | n/a (structural) | — |
| 2219 | @container stage (max-height: 480px) and (min-width: 500px) → .facet-row .pip | width | 7px | n/a (structural) | — |
| 2219 | @container stage (max-height: 480px) and (min-width: 500px) → .facet-row .pip | height | 7px | n/a (structural) | — |
| 2220 | @container stage (max-height: 480px) and (min-width: 500px) → .facet-row .pip:has(.facet-img), .facet-row .pip .facet-img | width | 12px | n/a (structural) | — |
| 2220 | @container stage (max-height: 480px) and (min-width: 500px) → .facet-row .pip:has(.facet-img), .facet-row .pip .facet-img | height | 12px | n/a (structural) | — |

## Intent

| styles.css line | selector | property | value | port | verdict |
| ---: | --- | --- | --- | --- | --- |
| 895 | .intent | gap | 4px | n/a (structural) | — |
| 896 | .intent | height | 30px | n/a (structural) | — |
| 896 | .intent | min-height | 30px | n/a (structural) | — |
| 896 | .intent | padding | 0 10px 0 6px | n/a (structural) | — |
| 896 | .intent | border-radius | 9px | not found | — |
| 897 | .intent | font-weight | 800 |  not found | — |
| 897 | .intent | font-size | 16.5px |  not found | — |
| 898 | .intent | border | 1.5px solid #05070e | presentation/combat/enemy_view.gd:74:const RAIL_EDGE: Color = Color(0.019607844, 0.02745098, 0.05490196)   # #05070e | — |
| 899 | .intent | background | linear-gradient(180deg, color-mix(in srgb, currentColor 20%, rgba(12, 15, 28, 0.85)), rgba(7, 9, 18, 0.88)) |  not found | — |
| 900 | .intent | box-shadow | 0 0 13px color-mix(in srgb, currentColor 30%, transparent), inset 0 0 9px color-mix(in srgb, currentColor 18%, transparent), inset 0 1px 0 rgba(255, 255, 255, 0.12) | not found | — |
| 903 | .intent | text-shadow | 0 0 8px currentColor | not found | — |
| 911 | .intent .ic | gap | 2px | n/a (structural) | — |
| 912 | .intent .ic | margin | -6px 2px -6px -16px | n/a (structural) | — |
| 912 | .intent .ic | position | relative | n/a (structural) | — |
| 912 | .intent .ic | z-index | 1 | n/a (structural) | — |
| 917 | .intent:not(:has(.num)) | padding | 0 8px | n/a (structural) | — |
| 920 | .intent:not(:has(.num)) .ic | margin | -6px 0 | n/a (structural) | — |
| 925 | .intent .ui-icon, .intent .gicon | width | 38px | n/a (structural) | — |
| 925 | .intent .ui-icon, .intent .gicon | height | 38px | n/a (structural) | — |
| 927 | .intent .ui-icon, .intent .gicon | filter | drop-shadow(0 0 0.75px currentColor) drop-shadow(0 0 1.25px currentColor) drop-shadow(0 0 2px color-mix(in srgb, currentColor 85%, transparent)) | not found | — |
| 932 | .intent .ic .ui-icon:nth-child(n+2), .intent .ic .gicon:nth-child(n+2) | width | 28px | n/a (structural) | — |
| 932 | .intent .ic .ui-icon:nth-child(n+2), .intent .ic .gicon:nth-child(n+2) | height | 28px | n/a (structural) | — |
| 933 | .intent.i-attack, .intent.i-attack_debuff, .intent.i-attack_block, .intent.i-attack_buff | color | #ff8d8d | presentation/run/run_style.gd:13:const DANGER: Color = Color("#ff8d8d") | — |
| 934 | .intent.i-block | color | var(--blk) | not found | — |
| 935 | .intent.i-buff | color | #a8ff9e | not found | — |
| 936 | .intent.i-debuff | color | #d8a0ff | not found | — |
| 937 | .intent.i-heal | color | var(--good) | not found | — |
| 942 | .dmg-preview | position | absolute | n/a (structural) | — |
| 942 | .dmg-preview | top | 26% | n/a (structural) | — |
| 942 | .dmg-preview | left | 50% | n/a (structural) | — |
| 942 | .dmg-preview | transform | translate(-50%, 0) scale(0.86) | n/a (structural) | — |
| 942 | .dmg-preview | z-index | 6 | n/a (structural) | — |
| 943 | .dmg-preview | gap | 5px | n/a (structural) | — |
| 943 | .dmg-preview | padding | 2px 11px | n/a (structural) | — |
| 943 | .dmg-preview | border-radius | 12px | not found | — |
| 944 | .dmg-preview | font-family | 'Cinzel', serif | not found | — |
| 944 | .dmg-preview | font-weight | 800 |  not found | — |
| 944 | .dmg-preview | font-size | 20px |  not found | — |
| 944 | .dmg-preview | color | #ffd9d9 | not found | — |
| 945 | .dmg-preview | background | rgba(10, 6, 12, 0.82) | presentation/combat/aim_arc.gd:6:## Drawn to match the benchmark's `aimMove` (`combat.js:1063`), which writes an | — |
| 945 | .dmg-preview | border | 1.5px solid rgba(255, 89, 100, 0.6) |  not found | — |
| 946 | .dmg-preview | box-shadow | 0 0 14px rgba(255, 89, 100, 0.35) | not found | — |
| 946 | .dmg-preview | text-shadow | 0 0 10px rgba(255, 90, 90, 0.85) | not found | — |
| 947 | .dmg-preview | opacity | 0 | not found | — |
| 949 | .dmg-preview.show | opacity | 1 |  not found | — |
| 949 | .dmg-preview.show | transform | translate(-50%, 0) scale(1) | n/a (structural) | — |
| 950 | .dmg-preview.dim | opacity | 0.4 |  not found | — |
| 952 | .dmg-preview.lethal | color | #fff | not found | — |
| 952 | .dmg-preview.lethal | border-color | rgba(255, 235, 235, 0.9) | presentation/combat/aim_arc.gd:14:## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with | — |
| 952 | .dmg-preview.lethal | background | rgba(46, 7, 12, 0.88) |  not found | — |
| 953 | .dmg-preview.lethal | box-shadow | 0 0 24px rgba(255, 130, 130, 0.7) | not found | — |
| 1061 | .intent.i-staggered | color | #ffd8a0 | presentation/combat/combat_screen.gd:242:const WARM_GOLD: Color = Color(1.0, 0.84705883, 0.627451)       # #ffd8a0 | — |
| 1061 | .intent.i-staggered | font-size | 13.5px |  not found | — |
| 1061 | .intent.i-staggered | letter-spacing | 0.06em |  not found | — |
| 1064 | .dmg-preview .pv-shatter | color | #ffd8a0 | presentation/combat/combat_screen.gd:242:const WARM_GOLD: Color = Color(1.0, 0.84705883, 0.627451)       # #ffd8a0 | — |
| 1064 | .dmg-preview .pv-shatter | filter | drop-shadow(0 0 6px rgba(255, 200, 120, 0.9)) | not found | — |
| 2132 | @container stage (max-width: 740px) → .intent | font-size | 14px |  not found | — |
| 2132 | @container stage (max-width: 740px) → .intent | gap | 4px | n/a (structural) | — |
| 2205 | @container stage (max-height: 480px) and (min-width: 500px) → .intent | font-size | 13px |  not found | — |

## Hand and cards

| styles.css line | selector | property | value | port | verdict |
| ---: | --- | --- | --- | --- | --- |
| 501 | .card | width | var(--cw) | n/a (structural) | — |
| 501 | .card | height | calc(var(--cw) * 1.42) | n/a (structural) | — |
| 501 | .card | position | relative | n/a (structural) | — |
| 504 | .card-lift | position | absolute | n/a (structural) | — |
| 504 | .card-lift | inset | 0 | n/a (structural) | — |
| 507 | .card-inner | position | absolute | n/a (structural) | — |
| 507 | .card-inner | inset | 0 | n/a (structural) | — |
| 507 | .card-inner | border-radius | 11px | not found | — |
| 508 | .card-inner | background | linear-gradient(168deg, color-mix(in srgb, var(--tint, #6f7fb0) 15%, rgba(16, 20, 36, 0.9)), rgba(9, 11, 20, 0.94) 58%) |  not found | — |
| 509 | .card-inner | border | 2px solid #05070e | presentation/combat/enemy_view.gd:74:const RAIL_EDGE: Color = Color(0.019607844, 0.02745098, 0.05490196)   # #05070e | — |
| 510 | .card-inner | box-shadow | 0 8px 22px rgba(0, 0, 0, 0.55), inset 0 0 0 1px color-mix(in srgb, var(--tint, #8fa3d8) 40%, transparent), inset 0 16px 30px -14px color-mix(in srgb, var(--tint, #8fa3d8) 34%, transparent) | not found | — |
| 516 | .card-inner | transform | none | n/a (structural) | — |
| 521 | .card.tilting .card-inner | transform | rotateX(var(--rx, 0deg)) rotateY(var(--ry, 0deg)) | n/a (structural) | — |
| 529 | .card-cost | position | absolute | n/a (structural) | — |
| 529 | .card-cost | top | -8px | n/a (structural) | — |
| 529 | .card-cost | left | -8px | n/a (structural) | — |
| 529 | .card-cost | z-index | 4 | n/a (structural) | — |
| 529 | .card-cost | width | 36px | n/a (structural) | — |
| 529 | .card-cost | height | 36px | n/a (structural) | — |
| 531 | .card-cost | font-family | 'Cinzel', serif | not found | — |
| 531 | .card-cost | font-weight | 800 |  not found | — |
| 531 | .card-cost | font-size | 17px |  not found | — |
| 531 | .card-cost | color | #241a05 | not found | — |
| 532 | .card-cost | background | linear-gradient(135deg, rgba(255, 255, 255, 0.55) 0%, transparent 28%), linear-gradient(315deg, rgba(122, 84, 23, 0.75) 0%, transparent 30%), conic-gradient(from 210deg at 50% 42%, #ffe9ac 0deg, #f2c14e 80deg, #b3831f 160deg, #f2c14e 240deg, #ffe9ac 360deg) | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 537 | .card-cost | filter | drop-shadow(0 3px 6px rgba(0, 0, 0, 0.65)) drop-shadow(0 0 8px rgba(242, 193, 78, 0.4)) | not found | — |
| 538 | .card-cost | text-shadow | 0 1px 0 rgba(255, 240, 200, 0.6) | not found | — |
| 541 | .card-cost::before | position | absolute | n/a (structural) | — |
| 541 | .card-cost::before | inset | 3px | n/a (structural) | — |
| 543 | .card-cost::before | background | linear-gradient(160deg, rgba(255, 255, 255, 0.35), transparent 42%, rgba(0, 0, 0, 0.22) 88%) | presentation/combat/aim_arc.gd:14:## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with | — |
| 547 | .card-cost.free | background | linear-gradient(135deg, rgba(255, 255, 255, 0.55) 0%, transparent 28%), linear-gradient(315deg, rgba(19, 91, 50, 0.8) 0%, transparent 30%), conic-gradient(from 210deg at 50% 42%, #d9fbe7 0deg, #37d67a 80deg, #17703e 160deg, #37d67a 240deg, #d9fbe7 360deg) | presentation/combat/aim_arc.gd:14:## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with | — |
| 551 | .card-cost.free | filter | drop-shadow(0 3px 6px rgba(0, 0, 0, 0.65)) drop-shadow(0 0 8px rgba(55, 214, 122, 0.45)) | not found | — |
| 553 | .card-art | height | 43% | n/a (structural) | — |
| 553 | .card-art | position | relative | n/a (structural) | — |
| 553 | .card-art | border-bottom | 1px solid #05070e | presentation/combat/enemy_view.gd:74:const RAIL_EDGE: Color = Color(0.019607844, 0.02745098, 0.05490196)   # #05070e | — |
| 553 | .card-art | background | radial-gradient(ellipse 90% 80% at 50% 45%, color-mix(in srgb, var(--tint, #8fa3d8) 14%, transparent), transparent 75%) |  not found | — |
| 555 | .card-art::after | position | absolute | n/a (structural) | — |
| 555 | .card-art::after | inset | 0 | n/a (structural) | — |
| 556 | .card-art::after | box-shadow | inset 0 1px 0 rgba(255, 255, 255, 0.09), inset 0 -1px 0 rgba(0, 0, 0, 0.65), inset 0 0 18px rgba(0, 0, 0, 0.35) | not found | — |
| 559 | .card-art svg | width | 100% | n/a (structural) | — |
| 559 | .card-art svg | height | 100% | n/a (structural) | — |
| 561 | .card-name | font-family | 'Cinzel', serif | not found | — |
| 561 | .card-name | font-weight | 700 |  not found | — |
| 561 | .card-name | font-size | 13.5px |  not found | — |
| 561 | .card-name | padding | 5px 6px 3px | n/a (structural) | — |
| 562 | .card-name | color | var(--parchment) | not found | — |
| 562 | .card-name | letter-spacing | 0.02em |  not found | — |
| 563 | .card-name | background | linear-gradient(90deg, transparent 4%, color-mix(in srgb, var(--gold) 22%, transparent) 18%, color-mix(in srgb, var(--gold) 22%, transparent) 82%, transparent 96%) top / 100% 1px no-repeat, linear-gradient(90deg, transparent 10%, color-mix(in srgb, var(--gold) 14%, transparent) 30%, color-mix(in srgb, var(--gold) 14%, transparent) 70%, transparent 90%) bottom / 100% 1px no-repeat, linear-gradient(180deg, rgba(255, 255, 255, 0.05), transparent) | not found | — |
| 568 | .card.upgraded .card-name | color | #9be8a8 | not found | — |
| 569 | .card-type | font-size | 10px |  not found | — |
| 569 | .card-type | letter-spacing | 0.28em |  not found | — |
| 569 | .card-type | color | var(--tint) | not found | — |
| 569 | .card-type | opacity | 0.9 |  not found | — |
| 570 | .card-text | padding | 4px 10px 10px | n/a (structural) | — |
| 570 | .card-text | font-size | 12.8px |  not found | — |
| 570 | .card-text | color | #c6ccdf | not found | — |
| 571 | .card-text .val | color | var(--parchment) | not found | — |
| 571 | .card-text .val | font-weight | 700 |  not found | — |
| 572 | .card-text .val.boosted | color | #8fe8a0 | presentation/combat/combat_screen.gd:249:const HEAL_GREEN: Color = Color(0.56078434, 0.9098039, 0.627451) # #8fe8a0 | — |
| 573 | .card-text .val.reduced | color | #ff8d8d | presentation/run/run_style.gd:13:const DANGER: Color = Color("#ff8d8d") | — |
| 574 | .card-text .kw | color | var(--tint) | not found | — |
| 574 | .card-text .kw | border-bottom | 1px dotted color-mix(in srgb, var(--tint) 60%, transparent) |  not found | — |
| 575 | .card-rarity | position | absolute | n/a (structural) | — |
| 575 | .card-rarity | bottom | 5px | n/a (structural) | — |
| 575 | .card-rarity | left | 50% | n/a (structural) | — |
| 575 | .card-rarity | transform | translateX(-50%) | n/a (structural) | — |
| 575 | .card-rarity | width | 24px | n/a (structural) | — |
| 575 | .card-rarity | height | 5px | n/a (structural) | — |
| 575 | .card-rarity | border-radius | 3px | not found | — |
| 578 | .card.r-uncommon .card-inner | box-shadow | 0 8px 22px rgba(0, 0, 0, 0.55), inset 0 0 0 1px rgba(168, 216, 238, 0.6), inset 0 16px 30px -14px color-mix(in srgb, var(--tint, #8fa3d8) 36%, transparent) | not found | — |
| 583 | .card.r-rare .card-inner | box-shadow | 0 8px 22px rgba(0, 0, 0, 0.55), 0 0 14px rgba(242, 193, 78, 0.16), inset 0 0 0 1px color-mix(in srgb, var(--gold) 80%, transparent), inset 0 16px 30px -14px color-mix(in srgb, var(--gold) 42%, transparent) | not found | — |
| 587 | .card.r-rare .card-inner | border-color | #1a1408 | not found | — |
| 588 | .r-common .card-rarity | background | #5d6a88 | not found | — |
| 589 | .r-uncommon .card-rarity | background | linear-gradient(90deg, #47c2e0, #7fe3f2) | not found | — |
| 589 | .r-uncommon .card-rarity | box-shadow | 0 0 6px #47c2e0 | not found | — |
| 590 | .r-rare .card-rarity | background | linear-gradient(90deg, var(--gold), #ffe9ac) | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 590 | .r-rare .card-rarity | box-shadow | 0 0 8px var(--gold) | not found | — |
| 591 | .r-starter .card-rarity | background | #3c465e | not found | — |
| 593 | .card.r-rare .card-inner::after | position | absolute | n/a (structural) | — |
| 593 | .card.r-rare .card-inner::after | inset | 0 | n/a (structural) | — |
| 594 | .card.r-rare .card-inner::after | background | linear-gradient(115deg, transparent 32%, rgba(255, 240, 190, 0.16) 46%, rgba(255, 255, 255, 0.05) 52%, transparent 66%) |  not found | — |
| 595 | .card.r-rare .card-inner::after | background-size | 260% 100% |  not found | — |
| 600 | .card-inner::before | position | absolute | n/a (structural) | — |
| 600 | .card-inner::before | inset | 0 | n/a (structural) | — |
| 600 | .card-inner::before | z-index | 3 | n/a (structural) | — |
| 600 | .card-inner::before | opacity | 0 | not found | — |
| 601 | .card-inner::before | background | radial-gradient(circle at var(--mx, 50%) var(--my, 50%), rgba(255, 255, 255, 0.17), transparent 55%) |  not found | — |
| 605 | .card.r-rare .card-inner::before | background | radial-gradient(circle at var(--mx, 50%) var(--my, 50%), rgba(255, 255, 255, 0.14), transparent 50%), linear-gradient(calc(115deg + var(--gx, 0) * 1deg), transparent 26%, rgba(255, 95, 180, 0.15) 40%, rgba(90, 220, 255, 0.17) 50%, rgba(140, 255, 170, 0.14) 60%, transparent 74%) |  not found | — |
| 609 | .card.unplayable-now .card-inner | filter | saturate(0.35) brightness(0.7) |  not found | — |
| 615 | .hand-zone | position | absolute | n/a (structural) | — |
| 615 | .hand-zone | left | 50% | n/a (structural) | — |
| 615 | .hand-zone | bottom | -12px | n/a (structural) | — |
| 615 | .hand-zone | height | 260px | n/a (structural) | — |
| 615 | .hand-zone | width | 680px | n/a (structural) | — |
| 616 | .hand-zone | margin-left | -340px | n/a (structural) | — |
| 616 | .hand-zone | z-index | 22 | n/a (structural) | — |
| 620 | .hand-zone .card | position | absolute | n/a (structural) | — |
| 620 | .hand-zone .card | left | 50% | n/a (structural) | — |
| 620 | .hand-zone .card | bottom | 8px | n/a (structural) | — |
| 621 | .hand-zone .card | width | calc(var(--cw) * var(--hand-scale)) | n/a (structural) | — |
| 621 | .hand-zone .card | height | calc(var(--cw) * var(--hand-scale) * 1.42) | n/a (structural) | — |
| 629 | .hand-zone .card.dragging | z-index | 46 !important | n/a (structural) | — |
| 630 | .hand-zone .card.dragging .card-inner | box-shadow | 0 24px 54px rgba(0, 0, 0, 0.75), 0 0 30px color-mix(in srgb, var(--tint) 45%, transparent) | not found | — |
| 631 | .hand-zone .card.will-cast .card-inner | box-shadow | 0 24px 54px rgba(0, 0, 0, 0.75), 0 0 44px color-mix(in srgb, var(--tint) 75%, transparent), inset 0 0 22px color-mix(in srgb, var(--tint) 35%, transparent) | not found | — |
| 634 | .hand-zone .card.lifted .card-lift | transform | translateY(-92px) scale(1.38) | n/a (structural) | — |
| 635 | .hand-zone .card.armed .card-lift | transform | translateY(-118px) scale(1.24) | n/a (structural) | — |
| 640 | .hand-zone .card.draw-pending | opacity | 0 | not found | — |
| 649 | .card.played-up | transform | translate(-50%, -240px) scale(0.72) !important | n/a (structural) | — |
| 649 | .card.played-up | opacity | 0 | not found | — |
| 650 | .card.exhausting | transform | translate(-50%, -140px) scale(0.6) rotate(8deg) !important | n/a (structural) | — |
| 650 | .card.exhausting | opacity | 0 | not found | — |
| 650 | .card.exhausting | filter | brightness(2.4) saturate(0.2) blur(2px) |  not found | — |
| 1125 | .hand-zone .card.will-burn | filter | sepia(0.35) saturate(1.45) brightness(1.08) |  not found | — |
| 1127 | .hand-zone .card.will-burn .card-inner | box-shadow | 0 24px 54px rgba(0, 0, 0, 0.75), 0 0 40px rgba(255, 170, 70, 0.8), inset 0 0 26px rgba(255, 150, 60, 0.35) | not found | — |
| 1543 | .flycard | position | absolute | n/a (structural) | — |
| 1543 | .flycard | width | 26px | n/a (structural) | — |
| 1543 | .flycard | height | 36px | n/a (structural) | — |
| 1543 | .flycard | border-radius | 8px | not found | — |
| 1543 | .flycard | z-index | 58 | n/a (structural) | — |
| 1544 | .flycard | background | linear-gradient(160deg, #1d2440, #0c101f 70%) | presentation/combat/card_edge.gdshader:38:uniform vec4 gold_dim : source_color = vec4(0.702, 0.514, 0.122, 1.0); | — |
| 1545 | .flycard | border | 1px solid rgba(242, 193, 78, 0.5) | not found | — |
| 1545 | .flycard | box-shadow | 0 3px 9px rgba(0, 0, 0, 0.6), inset 0 0 8px rgba(90, 110, 180, 0.3) | not found | — |
| 1548 | .flycard-back | background | radial-gradient(ellipse at 50% 38%, rgba(242, 193, 78, 0.28), transparent 52%), repeating-linear-gradient(135deg, rgba(255,255,255,0.03) 0 2px, transparent 2px 7px), linear-gradient(160deg, #2a3558, #0c101f 72%) |  not found | — |
| 1552 | .flycard-back | border | 1.5px solid rgba(242, 193, 78, 0.7) |  not found | — |
| 1553 | .flycard-back | box-shadow | 0 4px 14px rgba(0, 0, 0, 0.7), inset 0 0 14px rgba(120, 140, 210, 0.35) | not found | — |
| 1557 | .flycard-pile | border | 0 | not found | — |
| 1557 | .flycard-pile | border-radius | 6px | not found | — |
| 1557 | .flycard-pile | background-color | transparent | not found | — |
| 1558 | .flycard-pile | background-position | center | not found | — |
| 1558 | .flycard-pile | background-size | contain | not found | — |
| 1558 | .flycard-pile | background-repeat | no-repeat | not found | — |
| 1559 | .flycard-pile | box-shadow | 0 4px 12px rgba(0, 0, 0, 0.7) | not found | — |
| 1563 | .flycard-face | position | absolute | n/a (structural) | — |
| 1563 | .flycard-face | left | 0 | n/a (structural) | — |
| 1563 | .flycard-face | bottom | auto | n/a (structural) | — |
| 1563 | .flycard-face | z-index | 58 | n/a (structural) | — |
| 1566 | .flycard-face .card-lift | transform | none !important | n/a (structural) | — |
| 1567 | .flycard-face .card-inner | box-shadow | 0 6px 18px rgba(0, 0, 0, 0.75) | not found | — |
| 2045 | @media (prefers-reduced-motion: reduce) → .hand-zone .card.draw-pending | opacity | 1 |  not found | — |
| 2061 | @container stage (max-width: 1100px) → .hand-zone | height | 230px | n/a (structural) | — |
| 2135 | @container stage (max-width: 740px) → .card-text | font-size | 11.5px |  not found | — |
| 2135 | @container stage (max-width: 740px) → .card-text | padding | 3px 7px 8px | n/a (structural) | — |
| 2136 | @container stage (max-width: 740px) → .card-name | font-size | 12px |  not found | — |
| 2137 | @container stage (max-width: 740px) → .card-cost | width | 29px | n/a (structural) | — |
| 2137 | @container stage (max-width: 740px) → .card-cost | height | 29px | n/a (structural) | — |
| 2137 | @container stage (max-width: 740px) → .card-cost | font-size | 15px |  not found | — |
| 2137 | @container stage (max-width: 740px) → .card-cost | top | -6px | n/a (structural) | — |
| 2137 | @container stage (max-width: 740px) → .card-cost | left | -6px | n/a (structural) | — |
| 2138 | @container stage (max-width: 740px) → .hand-zone | height | 214px | n/a (structural) | — |
| 2139 | @container stage (max-width: 740px) → .hand-zone .card | bottom | 46px | n/a (structural) | — |
| 2207 | @container stage (max-height: 480px) and (min-width: 500px) → .card-text | font-size | 10.5px |  not found | — |
| 2208 | @container stage (max-height: 480px) and (min-width: 500px) → .card-name | font-size | 11px |  not found | — |
| 2209 | @container stage (max-height: 480px) and (min-width: 500px) → .card-cost | width | 27px | n/a (structural) | — |
| 2209 | @container stage (max-height: 480px) and (min-width: 500px) → .card-cost | height | 27px | n/a (structural) | — |
| 2209 | @container stage (max-height: 480px) and (min-width: 500px) → .card-cost | font-size | 14px |  not found | — |
| 2210 | @container stage (max-height: 480px) and (min-width: 500px) → .hand-zone | height | 128px | n/a (structural) | — |
| 2211 | @container stage (max-height: 480px) and (min-width: 500px) → .hand-zone .card | bottom | 0 | n/a (structural) | — |

## HUD buttons

| styles.css line | selector | property | value | port | verdict |
| ---: | --- | --- | --- | --- | --- |
| 1071 | .lantern-btn | position | absolute | n/a (structural) | — |
| 1071 | .lantern-btn | z-index | 24 | n/a (structural) | — |
| 1073 | .lantern-btn | border-radius | 0 | not found | — |
| 1073 | .lantern-btn | padding | 0 | n/a (structural) | — |
| 1074 | .lantern-btn | background | transparent | not found | — |
| 1074 | .lantern-btn | border | none | not found | — |
| 1074 | .lantern-btn | box-shadow | none | not found | — |
| 1075 | .lantern-btn | color | #ffca6e | not found | — |
| 1076 | .lantern-btn | font-family | 'Cinzel', serif | not found | — |
| 1081 | .lantern-btn .lb-ic | width | 100% | n/a (structural) | — |
| 1081 | .lantern-btn .lb-ic | height | 100% | n/a (structural) | — |
| 1083 | .lantern-btn .lb-ic | filter | drop-shadow(0 0 8px rgba(255, 180, 80, 0.85)) drop-shadow(0 2px 4px rgba(0, 0, 0, 0.75)) | not found | — |
| 1086 | .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | width | 94px | n/a (structural) | — |
| 1086 | .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | height | 94px | n/a (structural) | — |
| 1087 | .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | margin | 5px auto 0 | n/a (structural) | — |
| 1090 | .lantern-btn .lb-count | z-index | 1 | n/a (structural) | — |
| 1091 | .lantern-btn .lb-count | font-size | 26px |  not found | — |
| 1091 | .lantern-btn .lb-count | font-weight | 800 |  not found | — |
| 1092 | .lantern-btn .lb-count | color | #fff8e8 | presentation/combat/hud_bar.gd:63:const PALE: Color = Color(1.0, 0.973, 0.910)         # the big numerals #fff8e8 | — |
| 1095 | .lantern-btn .lb-count | text-shadow | -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000, 0 2px 5px rgba(0, 0, 0, 0.95) | not found | — |
| 1102 | .lantern-btn .lb-pips | z-index | 2 | n/a (structural) | — |
| 1103 | .lantern-btn .lb-pips | position | absolute | n/a (structural) | — |
| 1103 | .lantern-btn .lb-pips | inset | 0 | n/a (structural) | — |
| 1108 | .lantern-btn .lbp | position | absolute | n/a (structural) | — |
| 1108 | .lantern-btn .lbp | left | 50% | n/a (structural) | — |
| 1108 | .lantern-btn .lbp | top | 50% | n/a (structural) | — |
| 1108 | .lantern-btn .lbp | width | 5px | n/a (structural) | — |
| 1108 | .lantern-btn .lbp | height | 5px | n/a (structural) | — |
| 1108 | .lantern-btn .lbp | border-radius | 50% |  not found | — |
| 1109 | .lantern-btn .lbp | background | rgba(120, 100, 70, 0.35) |  not found | — |
| 1110 | .lantern-btn .lbp | transform | translate(-50%, -50%) rotate(var(--a)) translateY(calc(-1 * var(--lbr))) | n/a (structural) | — |
| 1113 | .lantern-btn .lbp.lit | background | radial-gradient(circle at 40% 35%, #fff6dd, #ffb35a 60%, #a05e18) |  not found | — |
| 1113 | .lantern-btn .lbp.lit | box-shadow | 0 0 6px rgba(255, 180, 90, 0.9) | not found | — |
| 1114 | .lantern-btn.unlit | filter | saturate(0.55) brightness(0.82) |  not found | — |
| 1120 | .lantern-btn.art-spent .lb-ic | opacity | 0.35 |  not found | — |
| 1255 | .energy-orb | position | absolute | n/a (structural) | — |
| 1256 | .energy-orb | width | auto | n/a (structural) | — |
| 1256 | .energy-orb | height | auto | n/a (structural) | — |
| 1256 | .energy-orb | min-height | 0 | n/a (structural) | — |
| 1256 | .energy-orb | padding | 0 | n/a (structural) | — |
| 1256 | .energy-orb | border-radius | 0 | not found | — |
| 1256 | .energy-orb | z-index | 26 | n/a (structural) | — |
| 1257 | .energy-orb | gap | 0 | n/a (structural) | — |
| 1259 | .energy-orb | background | transparent | not found | — |
| 1260 | .energy-orb | border | none | not found | — |
| 1261 | .energy-orb | box-shadow | none | not found | — |
| 1262 | .energy-orb | font-family | 'Cinzel', serif | not found | — |
| 1262 | .energy-orb | color | var(--parchment) | not found | — |
| 1267 | .energy-orb .num | position | relative | n/a (structural) | — |
| 1267 | .energy-orb .num | left | auto | n/a (structural) | — |
| 1267 | .energy-orb .num | top | auto | n/a (structural) | — |
| 1267 | .energy-orb .num | transform | none | n/a (structural) | — |
| 1268 | .energy-orb .num | margin-bottom | -10px | n/a (structural) | — |
| 1269 | .energy-orb .num | z-index | 2 | n/a (structural) | — |
| 1269 | .energy-orb .num | font-size | 44px |  not found | — |
| 1269 | .energy-orb .num | font-weight | 800 |  not found | — |
| 1270 | .energy-orb .num | color | #fff8e8 | presentation/combat/hud_bar.gd:63:const PALE: Color = Color(1.0, 0.973, 0.910)         # the big numerals #fff8e8 | — |
| 1273 | .energy-orb .num | text-shadow | -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000, 0 2px 5px rgba(0, 0, 0, 0.95) | not found | — |
| 1281 | .energy-orb.spent | filter | saturate(0.35) brightness(0.75) |  not found | — |
| 1285 | .energy-orb .candles | position | relative | n/a (structural) | — |
| 1285 | .energy-orb .candles | left | auto | n/a (structural) | — |
| 1285 | .energy-orb .candles | bottom | auto | n/a (structural) | — |
| 1285 | .energy-orb .candles | transform | none | n/a (structural) | — |
| 1286 | .energy-orb .candles | gap | 0 | n/a (structural) | — |
| 1288 | .energy-orb .candles | width | 120px | n/a (structural) | — |
| 1288 | .energy-orb .candles | min-width | 120px | n/a (structural) | — |
| 1288 | .energy-orb .candles | max-width | 120px | n/a (structural) | — |
| 1290 | .energy-orb .candles | z-index | 1 | n/a (structural) | — |
| 1294 | .candle | min-width | 0 | n/a (structural) | — |
| 1294 | .candle | max-width | 22px | n/a (structural) | — |
| 1295 | .candle | width | auto | n/a (structural) | — |
| 1295 | .candle | height | 30px | n/a (structural) | — |
| 1295 | .candle | border-radius | 50% 50% 46% 46% / 66% 66% 34% 34% |  not found | — |
| 1296 | .candle | background | #232a40 | not found | — |
| 1296 | .candle | border | 1px solid rgba(180, 195, 235, 0.16) |  not found | — |
| 1300 | .candle:has(.candle-img) | max-width | 40px | n/a (structural) | — |
| 1300 | .candle:has(.candle-img) | height | 56px | n/a (structural) | — |
| 1301 | .candle:has(.candle-img) | background | transparent | not found | — |
| 1301 | .candle:has(.candle-img) | border | none | not found | — |
| 1301 | .candle:has(.candle-img) | border-radius | 0 | not found | — |
| 1304 | .candle-img | width | 100% | n/a (structural) | — |
| 1304 | .candle-img | height | 100% | n/a (structural) | — |
| 1306 | .candle-img | filter | drop-shadow(0 1px 3px rgba(0, 0, 0, 0.7)) | not found | — |
| 1309 | .candle.is-spent .candle-img | filter | drop-shadow(0 1px 3px rgba(0, 0, 0, 0.7)) brightness(1.35) contrast(1.08) | not found | — |
| 1312 | .candle.lit | background | radial-gradient(circle at 50% 26%, #fff7d8, #ffc95e 52%, #b4701f 95%) |  not found | — |
| 1313 | .candle.lit | border-color | #ffe9ac | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 1314 | .candle.lit | box-shadow | 0 0 9px rgba(255, 190, 90, 0.9) | not found | — |
| 1318 | .candle.lit:has(.candle-img), .candle.is-lit:has(.candle-img) | background | transparent | not found | — |
| 1318 | .candle.lit:has(.candle-img), .candle.is-lit:has(.candle-img) | border | none | not found | — |
| 1318 | .candle.lit:has(.candle-img), .candle.is-lit:has(.candle-img) | box-shadow | none | not found | — |
| 1335 | .end-turn | position | absolute | n/a (structural) | — |
| 1335 | .end-turn | z-index | 24 | n/a (structural) | — |
| 1338 | .end-turn | padding | 0 | n/a (structural) | — |
| 1338 | .end-turn | margin | 0 | n/a (structural) | — |
| 1339 | .end-turn | background | transparent | not found | — |
| 1339 | .end-turn | border | none | not found | — |
| 1339 | .end-turn | border-radius | 0 | not found | — |
| 1340 | .end-turn | box-shadow | none | not found | — |
| 1341 | .end-turn | color | #fff6e0 | not found | — |
| 1342 | .end-turn | font-family | 'Cinzel', serif | not found | — |
| 1356 | .end-turn.ready .et-ic .ui-icon, .end-turn.ready .et-ic .gicon | filter | drop-shadow(0 2px 6px rgba(0, 0, 0, 0.75)) drop-shadow(0 0 10px rgba(255, 190, 90, 0.55)) drop-shadow(0 0 22px rgba(255, 180, 80, 0.4)) | not found | — |
| 1362 | .end-turn.ready .et-lbl | text-shadow | -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000, 0 2px 5px rgba(0, 0, 0, 0.95), 0 0 12px rgba(255, 200, 110, 0.75) | not found | — |
| 1371 | .end-turn .et-ic | width | 100% | n/a (structural) | — |
| 1371 | .end-turn .et-ic | height | 100% | n/a (structural) | — |
| 1375 | .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | width | 120px | n/a (structural) | — |
| 1375 | .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | height | 120px | n/a (structural) | — |
| 1376 | .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | filter | drop-shadow(0 2px 6px rgba(0, 0, 0, 0.75)) | not found | — |
| 1380 | .end-turn .et-lbl | z-index | 1 | n/a (structural) | — |
| 1381 | .end-turn .et-lbl | font-family | 'Cinzel', serif | not found | — |
| 1382 | .end-turn .et-lbl | font-size | 18px |  not found | — |
| 1382 | .end-turn .et-lbl | letter-spacing | 0.16em |  not found | — |
| 1382 | .end-turn .et-lbl | font-weight | 800 |  not found | — |
| 1384 | .end-turn .et-lbl | color | #fff8e8 | presentation/combat/hud_bar.gd:63:const PALE: Color = Color(1.0, 0.973, 0.910)         # the big numerals #fff8e8 | — |
| 1387 | .end-turn .et-lbl | text-shadow | -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000, 0 2px 5px rgba(0, 0, 0, 0.95) | not found | — |
| 1397 | .pile-btn | position | absolute | n/a (structural) | — |
| 1397 | .pile-btn | z-index | 24 | n/a (structural) | — |
| 1398 | .pile-btn | padding | 0 | n/a (structural) | — |
| 1398 | .pile-btn | border | 0 | not found | — |
| 1398 | .pile-btn | border-radius | 0 | not found | — |
| 1399 | .pile-btn | background | transparent | not found | — |
| 1399 | .pile-btn | box-shadow | none | not found | — |
| 1400 | .pile-btn | font-family | 'Cinzel', serif | not found | — |
| 1405 | .pile-stack | position | absolute | n/a (structural) | — |
| 1405 | .pile-stack | left | 0 | n/a (structural) | — |
| 1405 | .pile-stack | right | 0 | n/a (structural) | — |
| 1405 | .pile-stack | top | 0 | n/a (structural) | — |
| 1405 | .pile-stack | bottom | 18px | n/a (structural) | — |
| 1414 | .pile-stack-fallback | border-radius | 8px | not found | — |
| 1415 | .pile-stack-fallback | background | linear-gradient(160deg, rgba(36, 48, 86, 0.55), rgba(12, 16, 31, 0.35)) |  not found | — |
| 1419 | .pile-btn.is-empty .pile-stack-fallback | background | transparent | not found | — |
| 1423 | .pile-layer | position | absolute | n/a (structural) | — |
| 1423 | .pile-layer | left | 50% | n/a (structural) | — |
| 1423 | .pile-layer | bottom | 0 | n/a (structural) | — |
| 1424 | .pile-layer | width | 100% | n/a (structural) | — |
| 1424 | .pile-layer | height | auto | n/a (structural) | — |
| 1426 | .pile-layer | transform | translate(-50%, 0) rotate(var(--rot, 0deg)) | n/a (structural) | — |
| 1427 | .pile-layer | filter | drop-shadow(0 2px 4px rgba(0,0,0,0.65)) | not found | — |
| 1430 | .pile-btn .cnt | position | absolute | n/a (structural) | — |
| 1430 | .pile-btn .cnt | right | 2px | n/a (structural) | — |
| 1430 | .pile-btn .cnt | bottom | 16px | n/a (structural) | — |
| 1430 | .pile-btn .cnt | z-index | 2 | n/a (structural) | — |
| 1431 | .pile-btn .cnt | font-size | 16px |  not found | — |
| 1431 | .pile-btn .cnt | font-weight | 800 |  not found | — |
| 1431 | .pile-btn .cnt | color | var(--parchment) | not found | — |
| 1433 | .pile-btn .cnt | background | none | not found | — |
| 1433 | .pile-btn .cnt | border | 0 | not found | — |
| 1433 | .pile-btn .cnt | border-radius | 0 | not found | — |
| 1433 | .pile-btn .cnt | box-shadow | none | not found | — |
| 1433 | .pile-btn .cnt | padding | 0 | n/a (structural) | — |
| 1435 | .pile-btn .cnt | text-shadow | -1.5px -1.5px 0 #05070e, 1.5px -1.5px 0 #05070e, -1.5px 1.5px 0 #05070e, 1.5px 1.5px 0 #05070e, 0 0 4px rgba(0, 0, 0, 0.9) | presentation/combat/enemy_view.gd:74:const RAIL_EDGE: Color = Color(0.019607844, 0.02745098, 0.05490196)   # #05070e | — |
| 1443 | .pile-btn .lbl | position | absolute | n/a (structural) | — |
| 1443 | .pile-btn .lbl | left | 0 | n/a (structural) | — |
| 1443 | .pile-btn .lbl | right | 0 | n/a (structural) | — |
| 1443 | .pile-btn .lbl | bottom | 0 | n/a (structural) | — |
| 1443 | .pile-btn .lbl | z-index | 2 | n/a (structural) | — |
| 1444 | .pile-btn .lbl | font-size | 9.5px |  not found | — |
| 1444 | .pile-btn .lbl | font-weight | 700 |  not found | — |
| 1444 | .pile-btn .lbl | letter-spacing | 0.12em |  not found | — |
| 1445 | .pile-btn .lbl | color | var(--text-dim) | not found | — |
| 1446 | .pile-btn .lbl | text-shadow | 0 1px 3px rgba(0, 0, 0, 0.9) | not found | — |
| 1455 | .pile-exhaust | opacity | 0.9 |  not found | — |
| 2062 | @container stage (max-width: 1100px) → .energy-orb .num | font-size | 40px |  not found | — |
| 2063 | @container stage (max-width: 1100px) → .energy-orb .candles | width | 102px | n/a (structural) | — |
| 2063 | @container stage (max-width: 1100px) → .energy-orb .candles | min-width | 102px | n/a (structural) | — |
| 2063 | @container stage (max-width: 1100px) → .energy-orb .candles | max-width | 102px | n/a (structural) | — |
| 2064 | @container stage (max-width: 1100px) → .candle:has(.candle-img) | max-width | 34px | n/a (structural) | — |
| 2064 | @container stage (max-width: 1100px) → .candle:has(.candle-img) | height | 48px | n/a (structural) | — |
| 2066 | @container stage (max-width: 1100px) → .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | width | 84px | n/a (structural) | — |
| 2066 | @container stage (max-width: 1100px) → .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | height | 84px | n/a (structural) | — |
| 2067 | @container stage (max-width: 1100px) → .lantern-btn .lb-count | font-size | 22px |  not found | — |
| 2068 | @container stage (max-width: 1100px) → .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | width | 104px | n/a (structural) | — |
| 2068 | @container stage (max-width: 1100px) → .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | height | 104px | n/a (structural) | — |
| 2069 | @container stage (max-width: 1100px) → .end-turn .et-lbl | font-size | 16px |  not found | — |
| 2141 | @container stage (max-width: 740px) → .energy-orb .num | font-size | 36px | not found | — |
| 2142 | @container stage (max-width: 740px) → .energy-orb .candles | width | 84px | n/a (structural) | — |
| 2142 | @container stage (max-width: 740px) → .energy-orb .candles | min-width | 84px | n/a (structural) | — |
| 2142 | @container stage (max-width: 740px) → .energy-orb .candles | max-width | 84px | n/a (structural) | — |
| 2144 | @container stage (max-width: 740px) → .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | width | 68px | n/a (structural) | — |
| 2144 | @container stage (max-width: 740px) → .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | height | 68px | n/a (structural) | — |
| 2145 | @container stage (max-width: 740px) → .lantern-btn .lb-count | font-size | 20px |  not found | — |
| 2149 | @container stage (max-width: 740px) → .candle | max-width | 16px | n/a (structural) | — |
| 2149 | @container stage (max-width: 740px) → .candle | height | 22px | n/a (structural) | — |
| 2150 | @container stage (max-width: 740px) → .candle:has(.candle-img) | max-width | 28px | n/a (structural) | — |
| 2150 | @container stage (max-width: 740px) → .candle:has(.candle-img) | height | 40px | n/a (structural) | — |
| 2151 | @container stage (max-width: 740px) → .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | width | 96px | n/a (structural) | — |
| 2151 | @container stage (max-width: 740px) → .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | height | 96px | n/a (structural) | — |
| 2152 | @container stage (max-width: 740px) → .end-turn .et-lbl | font-size | 15px |  not found | — |
| 2152 | @container stage (max-width: 740px) → .end-turn .et-lbl | letter-spacing | 0.12em |  not found | — |
| 2153 | @container stage (max-width: 740px) → .pile-stack | left | 0 | n/a (structural) | — |
| 2153 | @container stage (max-width: 740px) → .pile-stack | right | 0 | n/a (structural) | — |
| 2153 | @container stage (max-width: 740px) → .pile-stack | top | 0 | n/a (structural) | — |
| 2153 | @container stage (max-width: 740px) → .pile-stack | bottom | 14px | n/a (structural) | — |
| 2154 | @container stage (max-width: 740px) → .pile-layer | width | 100% | n/a (structural) | — |
| 2155 | @container stage (max-width: 740px) → .pile-btn .cnt | font-size | 14px |  not found | — |
| 2155 | @container stage (max-width: 740px) → .pile-btn .cnt | right | 1px | n/a (structural) | — |
| 2155 | @container stage (max-width: 740px) → .pile-btn .cnt | bottom | 13px | n/a (structural) | — |
| 2156 | @container stage (max-width: 740px) → .pile-btn .lbl | font-size | 7.5px |  not found | — |
| 2156 | @container stage (max-width: 740px) → .pile-btn .lbl | letter-spacing | 0.08em |  not found | — |
| 2213 | @container stage (max-height: 480px) and (min-width: 500px) → .energy-orb .num | font-size | 33px |  not found | — |
| 2214 | @container stage (max-height: 480px) and (min-width: 500px) → .energy-orb .candles | width | 72px | n/a (structural) | — |
| 2214 | @container stage (max-height: 480px) and (min-width: 500px) → .energy-orb .candles | min-width | 72px | n/a (structural) | — |
| 2214 | @container stage (max-height: 480px) and (min-width: 500px) → .energy-orb .candles | max-width | 72px | n/a (structural) | — |
| 2216 | @container stage (max-height: 480px) and (min-width: 500px) → .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | width | 62px | n/a (structural) | — |
| 2216 | @container stage (max-height: 480px) and (min-width: 500px) → .lantern-btn .lb-ic .ui-icon, .lantern-btn .lb-ic .gicon | height | 62px | n/a (structural) | — |
| 2217 | @container stage (max-height: 480px) and (min-width: 500px) → .lantern-btn .lb-count | font-size | 18px |  not found | — |
| 2221 | @container stage (max-height: 480px) and (min-width: 500px) → .candle | max-width | 14px | n/a (structural) | — |
| 2221 | @container stage (max-height: 480px) and (min-width: 500px) → .candle | height | 18px | n/a (structural) | — |
| 2222 | @container stage (max-height: 480px) and (min-width: 500px) → .candle:has(.candle-img) | max-width | 24px | n/a (structural) | — |
| 2222 | @container stage (max-height: 480px) and (min-width: 500px) → .candle:has(.candle-img) | height | 34px | n/a (structural) | — |
| 2223 | @container stage (max-height: 480px) and (min-width: 500px) → .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | width | 84px | n/a (structural) | — |
| 2223 | @container stage (max-height: 480px) and (min-width: 500px) → .end-turn .et-ic .ui-icon, .end-turn .et-ic .gicon | height | 84px | n/a (structural) | — |
| 2224 | @container stage (max-height: 480px) and (min-width: 500px) → .end-turn .et-lbl | font-size | 14px |  not found | — |
| 2224 | @container stage (max-height: 480px) and (min-width: 500px) → .end-turn .et-lbl | letter-spacing | 0.1em |  not found | — |
| 2225 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-stack | left | 0 | n/a (structural) | — |
| 2225 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-stack | right | 0 | n/a (structural) | — |
| 2225 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-stack | top | 0 | n/a (structural) | — |
| 2225 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-stack | bottom | 14px | n/a (structural) | — |
| 2226 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-layer | width | 100% | n/a (structural) | — |
| 2227 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-btn .cnt | font-size | 14px |  not found | — |
| 2227 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-btn .cnt | right | 1px | n/a (structural) | — |
| 2227 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-btn .cnt | bottom | 13px | n/a (structural) | — |
| 2228 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-btn .lbl | font-size | 7px |  not found | — |
| 2228 | @container stage (max-height: 480px) and (min-width: 500px) → .pile-btn .lbl | letter-spacing | 0.08em |  not found | — |

## Screen dressing

| styles.css line | selector | property | value | port | verdict |
| ---: | --- | --- | --- | --- | --- |
| 66 | #vignette | position | fixed | n/a (structural) | — |
| 66 | #vignette | inset | 0 | n/a (structural) | — |
| 66 | #vignette | z-index | 4 | n/a (structural) | — |
| 67 | #vignette | background | radial-gradient(ellipse at 50% 45%, transparent 55%, rgba(4, 5, 12, 0.55) 100%) |  not found | — |
| 124 | #floaties | position | fixed | n/a (structural) | — |
| 124 | #floaties | inset | 0 | n/a (structural) | — |
| 124 | #floaties | z-index | 55 | n/a (structural) | — |
| 653 | .combat-screen | position | absolute | n/a (structural) | — |
| 653 | .combat-screen | inset | 0 | n/a (structural) | — |
| 656 | .stage-ledge | position | absolute | n/a (structural) | — |
| 656 | .stage-ledge | left | 0 | n/a (structural) | — |
| 656 | .stage-ledge | right | 0 | n/a (structural) | — |
| 656 | .stage-ledge | height | var(--glow-h) | n/a (structural) | — |
| 657 | .stage-ledge | bottom | calc(var(--ground-y) - var(--glow-h)) | n/a (structural) | — |
| 657 | .stage-ledge | z-index | 3 | n/a (structural) | — |
| 658 | .stage-ledge | background | linear-gradient(180deg, color-mix(in srgb, var(--ledge, #8fa3d8) 9%, transparent), transparent 62%) |  not found | — |
| 685 | .combat-screen .battlefield | z-index | 7 | n/a (structural) | — |
| 688 | .combat-screen .stage-dim | position | absolute | n/a (structural) | — |
| 688 | .combat-screen .stage-dim | inset | 0 | n/a (structural) | — |
| 688 | .combat-screen .stage-dim | z-index | 4 | n/a (structural) | — |
| 689 | .combat-screen .stage-dim | background | radial-gradient(circle var(--lr, 1500px) at var(--lx, 50%) var(--ly, 55%), transparent 42%, rgba(3, 4, 10, var(--la, 0)) 100%) |  not found | — |
| 692 | .stage-ledge::before | position | absolute | n/a (structural) | — |
| 692 | .stage-ledge::before | top | calc(-1 * var(--ledge-lip)) | n/a (structural) | — |
| 692 | .stage-ledge::before | left | 6% | n/a (structural) | — |
| 692 | .stage-ledge::before | right | 6% | n/a (structural) | — |
| 692 | .stage-ledge::before | height | 1.5px | n/a (structural) | — |
| 693 | .stage-ledge::before | background | linear-gradient(90deg, transparent, color-mix(in srgb, var(--ledge, #8fa3d8) 75%, #fff) 20% 80%, transparent) |  not found | — |
| 694 | .stage-ledge::before | opacity | 0.4 |  not found | — |
| 694 | .stage-ledge::before | box-shadow | 0 0 16px color-mix(in srgb, var(--ledge, #8fa3d8) 60%, transparent) | not found | — |
| 697 | .stage-breath | position | absolute | n/a (structural) | — |
| 697 | .stage-breath | width | 34cqw | n/a (structural) | — |
| 697 | .stage-breath | height | 26cqh | n/a (structural) | — |
| 697 | .stage-breath | border-radius | 50% |  not found | — |
| 697 | .stage-breath | z-index | 0 | n/a (structural) | — |
| 698 | .stage-breath | opacity | 0.1 |  not found | — |
| 698 | .stage-breath | filter | blur(40px) | not found | — |
| 699 | .stage-breath | background | radial-gradient(circle, var(--ledge, #8fa3d8) 0%, transparent 70%) | not found | — |
| 702 | .stage-breath.b1 | left | 6cqw | n/a (structural) | — |
| 702 | .stage-breath.b1 | bottom | calc(var(--ground-y) - 8cqh) | n/a (structural) | — |
| 703 | .stage-breath.b2 | right | 8cqw | n/a (structural) | — |
| 703 | .stage-breath.b2 | bottom | calc(var(--ground-y) - 12cqh) | n/a (structural) | — |
| 710 | @media (pointer: coarse) → .stage-breath | width | 24cqw | n/a (structural) | — |
| 710 | @media (pointer: coarse) → .stage-breath | height | 18cqh | n/a (structural) | — |
| 711 | @media (pointer: coarse) → .stage-breath | opacity | 0.08 | presentation/combat/card_surface.gd:91:		"soak": 0.0, "bleed": 0.08, | — |
| 711 | @media (pointer: coarse) → .stage-breath | filter | none | not found | — |
| 714 | @media (pointer: coarse) → .stage-breath.b1 | bottom | calc(var(--ground-y) - 5cqh) | n/a (structural) | — |
| 715 | @media (pointer: coarse) → .stage-breath.b2 | bottom | calc(var(--ground-y) - 8cqh) | n/a (structural) | — |
| 717 | @media (prefers-reduced-motion: reduce) → .stage-breath | opacity | 0.08 | presentation/combat/card_surface.gd:91:		"soak": 0.0, "bleed": 0.08, | — |
| 719 | .stage-ledge, .stage-breath | opacity | 0 | not found | — |
| 721 | .combat-screen::after | position | absolute | n/a (structural) | — |
| 721 | .combat-screen::after | left | 0 | n/a (structural) | — |
| 721 | .combat-screen::after | right | 0 | n/a (structural) | — |
| 721 | .combat-screen::after | bottom | 0 | n/a (structural) | — |
| 721 | .combat-screen::after | height | 300px | n/a (structural) | — |
| 721 | .combat-screen::after | z-index | 2 | n/a (structural) | — |
| 722 | .combat-screen::after | background | linear-gradient(180deg, transparent, rgba(5, 7, 14, 0.55) 75%) |  not found | — |
| 731 | .battlefield | position | absolute | n/a (structural) | — |
| 731 | .battlefield | left | 0 | n/a (structural) | — |
| 731 | .battlefield | right | 0 | n/a (structural) | — |
| 731 | .battlefield | top | 0 | n/a (structural) | — |
| 731 | .battlefield | bottom | var(--ground-y) | n/a (structural) | — |
| 734 | .player-zone | transform | none | n/a (structural) | — |
| 1065 | .floaty.shatterf | font-size | 15px |  not found | — |
| 1065 | .floaty.shatterf | letter-spacing | 0.2em |  not found | — |
| 1065 | .floaty.shatterf | color | #9fd4ff | presentation/combat/combat_screen.gd:240:const WARD_BLUE: Color = Color(0.62352943, 0.83137256, 1.0)     # #9fd4ff | — |
| 1065 | .floaty.shatterf | font-family | 'Cinzel', serif | not found | — |
| 1065 | .floaty.shatterf | text-shadow | var(--ink), 0 0 18px rgba(170, 215, 255, 1), 0 3px 6px #000 | not found | — |
| 1066 | .floaty.staggerf | color | #ffd8a0 | presentation/combat/combat_screen.gd:242:const WARM_GOLD: Color = Color(1.0, 0.84705883, 0.627451)       # #ffd8a0 | — |
| 1066 | .floaty.staggerf | font-size | 24px |  not found | — |
| 1066 | .floaty.staggerf | letter-spacing | 0.1em |  not found | — |
| 1066 | .floaty.staggerf | text-shadow | var(--ink), 0 0 14px rgba(255, 195, 120, 0.95), 0 3px 6px #000 | not found | — |
| 1121 | .floaty.artf | color | #ffe9ac | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 1121 | .floaty.artf | font-size | 26px |  not found | — |
| 1121 | .floaty.artf | letter-spacing | 0.12em |  not found | — |
| 1121 | .floaty.artf | text-shadow | var(--ink), 0 0 16px rgba(255, 200, 110, 0.95), 0 3px 6px #000 | not found | — |
| 1122 | .art-cast | position | fixed | n/a (structural) | — |
| 1122 | .art-cast | width | 110px | n/a (structural) | — |
| 1122 | .art-cast | height | 110px | n/a (structural) | — |
| 1122 | .art-cast | z-index | 57 | n/a (structural) | — |
| 1122 | .art-cast | filter | drop-shadow(0 0 24px rgba(255, 217, 122, 0.5)) | not found | — |
| 1154 | .turn-banner.omen-banner | font-size | 30px |  not found | — |
| 1154 | .turn-banner.omen-banner | letter-spacing | 0.14em |  not found | — |
| 1154 | .turn-banner.omen-banner | padding | 18px 34px 14px | n/a (structural) | — |
| 1155 | .turn-banner.omen-banner | background | linear-gradient(180deg, rgba(10, 8, 18, 0.92), rgba(7, 6, 14, 0.88)) | presentation/combat/aim_arc.gd:6:## Drawn to match the benchmark's `aimMove` (`combat.js:1063`), which writes an | — |
| 1156 | .turn-banner.omen-banner | border-top | 1px solid rgba(255, 233, 172, 0.35) | presentation/combat/aim_arc.gd:14:## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with | — |
| 1156 | .turn-banner.omen-banner | border-bottom | 1px solid rgba(255, 233, 172, 0.35) | presentation/combat/aim_arc.gd:14:## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with | — |
| 1177 | .turn-banner.eighth-floor-echo | top | 23% | n/a (structural) | — |
| 1177 | .turn-banner.eighth-floor-echo | gap | 12px | n/a (structural) | — |
| 1178 | .turn-banner.eighth-floor-echo | width | min(680px, 88cqw) | n/a (structural) | — |
| 1178 | .turn-banner.eighth-floor-echo | padding | 11px 24px | n/a (structural) | — |
| 1179 | .turn-banner.eighth-floor-echo | color | #e8e0ff | not found | — |
| 1179 | .turn-banner.eighth-floor-echo | border-color | rgba(232, 224, 255, 0.38) |  not found | — |
| 1180 | .turn-banner.eighth-floor-echo | background | rgba(8, 7, 17, 0.9) |  not found | — |
| 1180 | .turn-banner.eighth-floor-echo | font-size | clamp(15px, 2.1cqw, 20px) |  not found | — |
| 1181 | .turn-banner.eighth-floor-echo | letter-spacing | 0.15em |  not found | — |
| 1195 | @media (prefers-reduced-motion: reduce) → .turn-banner.omen-banner.broken-omen, .turn-banner.eighth-floor-echo | opacity | 1 |  not found | — |
| 1195 | @media (prefers-reduced-motion: reduce) → .turn-banner.omen-banner.broken-omen, .turn-banner.eighth-floor-echo | transform | translate(-50%, -50%) | n/a (structural) | — |
| 1229 | .turn-banner.perfect-banner | color | #ffe9ac | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 1229 | .turn-banner.perfect-banner | letter-spacing | 0.4em |  not found | — |
| 1230 | .turn-banner.perfect-banner | text-shadow | 0 0 34px rgba(242, 193, 78, 0.85), 0 4px 12px #000 | not found | — |
| 1234 | .perfect-seal | font-family | 'Cinzel', serif | not found | — |
| 1234 | .perfect-seal | font-size | 13.5px |  not found | — |
| 1234 | .perfect-seal | letter-spacing | 0.18em |  not found | — |
| 1235 | .perfect-seal | color | #ffe9ac | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 1235 | .perfect-seal | text-shadow | 0 0 12px rgba(242, 193, 78, 0.6) | not found | — |
| 1235 | .perfect-seal | margin | 6px 0 | n/a (structural) | — |
| 1457 | .turn-banner | position | absolute | n/a (structural) | — |
| 1457 | .turn-banner | top | 34% | n/a (structural) | — |
| 1457 | .turn-banner | left | 50% | n/a (structural) | — |
| 1457 | .turn-banner | transform | translate(-50%, -50%) | n/a (structural) | — |
| 1457 | .turn-banner | z-index | 42 | n/a (structural) | — |
| 1458 | .turn-banner | font-family | 'Cinzel', serif | not found | — |
| 1458 | .turn-banner | font-size | 42px | not found | — |
| 1458 | .turn-banner | font-weight | 800 |  not found | — |
| 1458 | .turn-banner | letter-spacing | 0.3em |  not found | — |
| 1458 | .turn-banner | color | var(--parchment) | not found | — |
| 1459 | .turn-banner | background | var(--glass-fill) | not found | — |
| 1459 | .turn-banner | border-top | 1px solid var(--gold-line) | not found | — |
| 1459 | .turn-banner | border-bottom | 1px solid var(--gold-line) | not found | — |
| 1459 | .turn-banner | padding | 10px 40px | n/a (structural) | — |
| 1460 | .turn-banner | text-shadow | 0 0 30px rgba(242, 193, 78, 0.6), 0 4px 12px #000 | not found | — |
| 1470 | .turn-banner.boss-banner | gap | 0.7em | n/a (structural) | — |
| 1471 | .turn-banner.boss-banner | font-size | clamp(38px, 5.4cqw, 62px) |  not found | — |
| 1471 | .turn-banner.boss-banner | letter-spacing | 0.22em |  not found | — |
| 1471 | .turn-banner.boss-banner | color | #ffb3ef | not found | — |
| 1471 | .turn-banner.boss-banner | top | 38% | n/a (structural) | — |
| 1472 | .turn-banner.boss-banner | text-shadow | 0 0 44px rgba(255, 79, 216, 0.7), 0 6px 16px #000 | not found | — |
| 1477 | .turn-banner.boss-banner::before, .turn-banner.boss-banner::after | font-size | 0.45em |  not found | — |
| 1477 | .turn-banner.boss-banner::before, .turn-banner.boss-banner::after | opacity | 0.75 |  not found | — |
| 1494 | .combat-msg | position | absolute | n/a (structural) | — |
| 1494 | .combat-msg | top | 100px | n/a (structural) | — |
| 1494 | .combat-msg | left | 50% | n/a (structural) | — |
| 1494 | .combat-msg | transform | translateX(-50%) | n/a (structural) | — |
| 1494 | .combat-msg | color | var(--text-dim) | not found | — |
| 1494 | .combat-msg | font-size | 14px |  not found | — |
| 1494 | .combat-msg | letter-spacing | .14em |  not found | — |
| 1494 | .combat-msg | font-family | 'Cinzel', serif | not found | — |
| 1494 | .combat-msg | z-index | 26 | n/a (structural) | — |
| 1499 | .floaty | position | absolute | n/a (structural) | — |
| 1499 | .floaty | transform | translate(-50%, -50%) | n/a (structural) | — |
| 1499 | .floaty | font-family | 'Cinzel', serif | not found | — |
| 1499 | .floaty | font-weight | 800 |  not found | — |
| 1499 | .floaty | font-size | 32px |  not found | — |
| 1500 | .floaty | color | #fff | not found | — |
| 1501 | .floaty | text-shadow | var(--ink), 0 0 12px rgba(255, 90, 90, 0.9), 0 3px 6px #000 | not found | — |
| 1503 | .floaty.dmg | color | #ffe2e2 | presentation/combat/floaters.gd:26:	"dmg": Color(1.0, 0.8862745, 0.8862745),           # #ffe2e2 | — |
| 1503 | .floaty.dmg | text-shadow | var(--ink), 0 0 14px rgba(255, 110, 110, 0.95), 0 3px 6px #000 | not found | — |
| 1504 | .floaty.dmg-big | font-size | 42px | not found | — |
| 1505 | .floaty.dmg-kill | font-size | 52px |  not found | — |
| 1505 | .floaty.dmg-kill | text-shadow | var(--ink), 0 0 22px currentColor, 0 2px 4px #000 | not found | — |
| 1506 | .floaty.dmg-overkill | font-size | 62px |  not found | — |
| 1506 | .floaty.dmg-overkill | text-shadow | var(--ink), 0 0 30px currentColor, 0 2px 6px #000 | not found | — |
| 1507 | .floaty.crit | font-size | 47px | not found | — |
| 1507 | .floaty.crit | letter-spacing | 0.02em |  not found | — |
| 1507 | .floaty.crit | color | #ffd8a0 | presentation/combat/combat_screen.gd:242:const WARM_GOLD: Color = Color(1.0, 0.84705883, 0.627451)       # #ffd8a0 | — |
| 1507 | .floaty.crit | text-shadow | var(--ink), 0 0 22px rgba(255, 160, 60, 1), 0 0 46px rgba(255, 120, 40, 0.55), 0 4px 8px #000 | not found | — |
| 1508 | .floaty.blockedf | color | #bfd4e8 | presentation/combat/floaters.gd:28:	"blockedf": Color(0.7490196, 0.83137256, 0.9098039), # #bfd4e8 | — |
| 1508 | .floaty.blockedf | font-size | 22px |  not found | — |
| 1508 | .floaty.blockedf | text-shadow | var(--ink), 0 0 10px rgba(127, 212, 255, 0.8), 0 3px 6px #000 | not found | — |
| 1509 | .floaty.healf | color | #b9f0c3 | presentation/combat/floaters.gd:29:	"healf": Color(0.7254902, 0.9411765, 0.7647059),   # #b9f0c3 | — |
| 1509 | .floaty.healf | text-shadow | var(--ink), 0 0 12px rgba(80, 220, 120, 0.9), 0 3px 6px #000 | not found | — |
| 1510 | .floaty.poisonf | color | #d3f2a1 | presentation/combat/floaters.gd:30:	"poisonf": Color(0.827451, 0.9490196, 0.6313726),  # #d3f2a1 | — |
| 1510 | .floaty.poisonf | text-shadow | var(--ink), 0 0 12px rgba(140, 220, 60, 0.9), 0 3px 6px #000 | not found | — |
| 1511 | .floaty.blockf | color | #cdeeff | presentation/combat/floaters.gd:31:	"blockf": Color(0.8039216, 0.93333334, 1.0),       # #cdeeff | — |
| 1511 | .floaty.blockf | text-shadow | var(--ink), 0 0 12px rgba(127, 212, 255, 0.9), 0 3px 6px #000 | not found | — |
| 1512 | .floaty.goldf | color | #ffe9ac | presentation/combat/floaters.gd:32:	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac | — |
| 1512 | .floaty.goldf | text-shadow | var(--ink), 0 0 12px rgba(242, 193, 78, 0.95), 0 3px 6px #000 | not found | — |
| 1513 | .floaty.bufff | color | #cfe3ff | presentation/combat/floaters.gd:33:	"bufff": Color(0.8117647, 0.8901961, 1.0),         # #cfe3ff | — |
| 1513 | .floaty.bufff | font-size | 22px |  not found | — |
| 1513 | .floaty.bufff | text-shadow | var(--ink), 0 0 10px rgba(150, 180, 255, 0.9), 0 3px 6px #000 | not found | — |
| 1514 | .floaty.debufff | color | #e8c8ff | presentation/combat/floaters.gd:34:	"debufff": Color(0.9098039, 0.78431374, 1.0),      # #e8c8ff | — |
| 1514 | .floaty.debufff | font-size | 22px |  not found | — |
| 1514 | .floaty.debufff | text-shadow | var(--ink), 0 0 10px rgba(200, 120, 255, 0.9), 0 3px 6px #000 | not found | — |
| 1515 | .floaty.movef | font-size | 14px |  not found | — |
| 1515 | .floaty.movef | letter-spacing | 0.14em |  not found | — |
| 1515 | .floaty.movef | font-family | 'Cinzel', serif | not found | — |
| 1515 | .floaty.movef | background | var(--glass-fill) | not found | — |
| 1515 | .floaty.movef | border | 1px solid var(--gold-line) | not found | — |
| 1515 | .floaty.movef | border-radius | 6px | not found | — |
| 1515 | .floaty.movef | padding | 4px 12px | n/a (structural) | — |
| 1515 | .floaty.movef | color | var(--parchment) | not found | — |
| 1516 | .floaty.notice | font-size | 20px |  not found | — |
| 1516 | .floaty.notice | color | var(--parchment) | not found | — |
| 1516 | .floaty.notice | letter-spacing | .08em | not found | — |
| 1516 | .floaty.notice | text-shadow | var(--ink), 0 3px 6px #000 | not found | — |
| 2157 | @container stage (max-width: 740px) → .turn-banner | font-size | 27px |  not found | — |
| 2157 | @container stage (max-width: 740px) → .turn-banner | letter-spacing | 0.2em |  not found | — |
| 2158 | @container stage (max-width: 740px) → .turn-banner.boss-banner | font-size | clamp(24px, 7cqw, 38px) | not found | — |
| 2159 | @container stage (max-width: 740px) → .combat-msg | top | calc(78px + var(--sat)) | n/a (structural) | — |
| 2159 | @container stage (max-width: 740px) → .combat-msg | font-size | 12px |  not found | — |
| 2160 | @container stage (max-width: 740px) → .floaty | font-size | 26px |  not found | — |
| 2161 | @container stage (max-width: 740px) → .floaty.dmg-big | font-size | 30px |  not found | — |
| 2162 | @container stage (max-width: 740px) → .floaty.dmg-kill | font-size | 38px |  not found | — |
| 2163 | @container stage (max-width: 740px) → .floaty.dmg-overkill | font-size | 44px |  not found | — |
| 2164 | @container stage (max-width: 740px) → .floaty.crit | font-size | 36px | not found | — |
| 2165 | @container stage (max-width: 740px) → .floaty.blockedf, .floaty.bufff, .floaty.debufff | font-size | 18px |  not found | — |
| 2166 | @container stage (max-width: 740px) → .floaty.notice | font-size | 16px |  not found | — |
| 2229 | @container stage (max-height: 480px) and (min-width: 500px) → .turn-banner | font-size | 26px |  not found | — |
| 2230 | @container stage (max-height: 480px) and (min-width: 500px) → .floaty | font-size | 22px |  not found | — |
| 2231 | @container stage (max-height: 480px) and (min-width: 500px) → .floaty.crit | font-size | 32px |  not found | — |

## State-rules appendix

| styles.css line | selector | state |
| ---: | --- | --- |

## Completeness

- In-scope selector-rule count: 392.
- Static declaration rows emitted: 922.
- Skipped from main tables: 8 interaction-state rules in the appendix; animation, transition and keyframe declarations; properties outside the requested families.
- No selector was dropped as DEAD: the requested method forbids markup inspection, so CSS alone cannot prove a conditional selector is absent at runtime.
- Included despite uncertainty rather than dropped: `.card-grid .card`, `.choice-cards .card`, `#vignette`, and global combat-effect classes (for example `.turn-banner` and `.floaty`). Stylesheet evidence alone does not prove their runtime presence or absence during a fight.

