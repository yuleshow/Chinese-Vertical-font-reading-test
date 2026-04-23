#!/usr/bin/env python3
"""Study how fonts handle vertical punctuation - cmap vs GSUB vert coverage."""
import os, sys, glob
from fontTools.ttLib import TTFont

FONT_DIR = "/Users/yuleshow/yuleshow-github/Chinese-Fonts"

# Characters to check: label, base codepoint, vertical form codepoint
CHECKS = [
    ("：", 0xFF1A, 0xFE13),
    ("；", 0xFF1B, 0xFE14),
    ("（", 0xFF08, 0xFE35),
    ("）", 0xFF09, 0xFE36),
    ("「", 0x300C, 0xFE41),
    ("」", 0x300D, 0xFE42),
    ("『", 0x300E, 0xFE43),
    ("』", 0x300F, 0xFE44),
    ("《", 0x300A, 0xFE3D),
    ("》", 0x300B, 0xFE3E),
    ("〈", 0x3008, 0xFE3F),
    ("〉", 0x3009, 0xFE40),
    ("【", 0x3010, 0xFE3B),
    ("】", 0x3011, 0xFE3C),
]

def get_vert_coverage(font):
    """Get set of glyph names covered by GSUB vert/vrt2 features."""
    if 'GSUB' not in font:
        return set()
    gsub = font['GSUB'].table
    if not gsub.FeatureList or not gsub.LookupList:
        return set()
    
    # Find lookup indices for vert/vrt2
    vert_lookups = set()
    for feat in gsub.FeatureList.FeatureRecord:
        if feat.FeatureTag in ('vert', 'vrt2'):
            vert_lookups.update(feat.Feature.LookupListIndex)
    
    if not vert_lookups:
        return set()
    
    # Collect covered glyph names from those lookups
    covered = set()
    for idx in vert_lookups:
        if idx >= len(gsub.LookupList.Lookup):
            continue
        lookup = gsub.LookupList.Lookup[idx]
        for sub in lookup.SubTable:
            if hasattr(sub, 'mapping'):  # SingleSubst
                covered.update(sub.mapping.keys())
    return covered

def analyze_font(path):
    try:
        if path.endswith('.ttc'):
            from fontTools.ttLib import TTCollection
            ttc = TTCollection(path)
            fonts = [(f"{os.path.basename(path)}[{i}]", f) for i, f in enumerate(ttc.fonts)]
        else:
            fonts = [(os.path.basename(path), TTFont(path))]
    except Exception as e:
        return
    
    for name, font in fonts:
        cmap = font.getBestCmap()
        if not cmap:
            continue
        
        vert_covered = get_vert_coverage(font)
        
        issues = []
        for label, base_cp, vert_cp in CHECKS:
            if base_cp not in cmap:
                continue  # base char missing, skip
            
            base_glyph = cmap[base_cp]
            vert_glyph = cmap.get(vert_cp)
            in_vert_gsub = base_glyph in vert_covered
            
            # Determine status
            if vert_glyph and base_glyph == vert_glyph:
                # Base and vert form map to SAME glyph - likely already vertical
                status = "SAME_GLYPH"
            elif vert_glyph:
                # Has separate vertical form glyph in cmap
                status = "HAS_VERT_CMAP"
            elif in_vert_gsub:
                # No vert cmap but GSUB will substitute
                status = "HAS_GSUB_VERT"
            else:
                # No vertical support at all
                status = "NO_VERT"
                issues.append(label)
        
        if issues or True:  # Print all fonts
            has_gsub = 'GSUB' in font
            has_vert_feat = bool(vert_covered)
            print(f"\n{'='*60}")
            print(f"Font: {name}")
            print(f"  GSUB: {has_gsub}, vert/vrt2 feature: {has_vert_feat}, vert coverage: {len(vert_covered)} glyphs")
            for label, base_cp, vert_cp in CHECKS:
                if base_cp not in cmap:
                    print(f"  {label} U+{base_cp:04X}: BASE MISSING")
                    continue
                base_glyph = cmap[base_cp]
                vert_glyph = cmap.get(vert_cp)
                in_gsub = base_glyph in vert_covered
                
                parts = [f"base={base_glyph}"]
                if vert_glyph:
                    parts.append(f"vert_cmap={vert_glyph}")
                    if base_glyph == vert_glyph:
                        parts.append("SAME!")
                if in_gsub:
                    parts.append("IN_GSUB")
                if not vert_glyph and not in_gsub:
                    parts.append("⚠ NO_VERT")
                print(f"  {label} U+{base_cp:04X} → U+{vert_cp:04X}: {', '.join(parts)}")

# Find all fonts
font_files = []
for ext in ('*.ttf', '*.otf', '*.ttc'):
    font_files.extend(glob.glob(os.path.join(FONT_DIR, '**', ext), recursive=True))

font_files.sort()
for f in font_files:
    analyze_font(f)
