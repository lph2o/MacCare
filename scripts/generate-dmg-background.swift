import AppKit
import CoreGraphics
import Foundation

// Génère les images de fond Retina (@1x et @2x) pour l'installateur DMG de MacCare.
// Dimensions logiques : 720 x 460 pt (1440 x 920 px @2x).

let logicalWidth: CGFloat = 720
let logicalHeight: CGFloat = 460

func drawDMGBackground(scale: CGFloat) -> NSBitmapImageRep? {
    let pixelWidth = Int(logicalWidth * scale)
    let pixelHeight = Int(logicalHeight * scale)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }
    rep.size = NSSize(width: logicalWidth, height: logicalHeight)

    NSGraphicsContext.saveGraphicsState()
    guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    // On utilise un repère avec origine en HAUT à gauche (comme Finder) pour aligner parfaitement les icônes.
    ctx.translateBy(x: 0, y: logicalHeight)
    ctx.scaleBy(x: 1.0, y: -1.0)

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 1. Fond principal : dégradé profond Obsidian / Aubergine / Indigo
    let bgColors = [
        NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.11, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.09, green: 0.07, blue: 0.18, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.13, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.52, 1.0]) {
        ctx.drawLinearGradient(
            bgGrad,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: logicalWidth, y: logicalHeight),
            options: []
        )
    }

    // 2. Halos lumineux radiaux (sous MacCare à gauche, au centre, et sous Applications à droite)
    func drawRadialGlow(center: CGPoint, radius: CGFloat, color: NSColor) {
        let colors = [
            color.cgColor,
            color.withAlphaComponent(color.alphaComponent * 0.35).cgColor,
            NSColor.clear.cgColor
        ] as CFArray
        if let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.45, 1.0]) {
            ctx.drawRadialGradient(
                grad,
                startCenter: center,
                startRadius: 2,
                endCenter: center,
                endRadius: radius,
                options: []
            )
        }
    }

    // Halo Violet/Magenta sous MacCare.app (x=195, y=232)
    drawRadialGlow(
        center: CGPoint(x: 195, y: 232),
        radius: 175,
        color: NSColor(calibratedRed: 0.62, green: 0.22, blue: 0.96, alpha: 0.30)
    )
    // Halo Cyan central sous la flèche (x=360, y=232)
    drawRadialGlow(
        center: CGPoint(x: 360, y: 232),
        radius: 135,
        color: NSColor(calibratedRed: 0.12, green: 0.82, blue: 0.98, alpha: 0.18)
    )
    // Halo Bleu Azur sous Applications (x=525, y=232)
    drawRadialGlow(
        center: CGPoint(x: 525, y: 232),
        radius: 175,
        color: NSColor(calibratedRed: 0.08, green: 0.56, blue: 1.0, alpha: 0.30)
    )

    // 3. Grille architecturale subtile en arrière-plan
    ctx.saveGState()
    ctx.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.025).cgColor)
    ctx.setLineWidth(1.0)
    for x in stride(from: CGFloat(40), to: logicalWidth, by: 40) {
        ctx.move(to: CGPoint(x: x, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: logicalHeight))
    }
    for y in stride(from: CGFloat(40), to: logicalHeight, by: 40) {
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: logicalWidth, y: y))
    }
    ctx.strokePath()
    ctx.restoreGState()

    // Fonction utilitaire pour dessiner un rectangle arrondi dans le repère inversé
    func addRoundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    // Fonction utilitaire pour dessiner du texte centré en coordonnées top-down
    func drawCenteredText(
        _ text: String,
        centerX: CGFloat,
        topY: CGFloat,
        font: NSFont,
        color: NSColor,
        kern: CGFloat = 0.0
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        if kern != 0 {
            attrs[.kern] = kern
        }
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()
        let drawRect = CGRect(x: centerX - size.width / 2.0, y: topY, width: size.width + 8, height: size.height + 4)

        ctx.saveGState()
        // Pour que NSAttributedString dessine à l'endroit dans notre contexte inversé :
        ctx.translateBy(x: drawRect.minX, y: drawRect.minY + size.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        attrStr.draw(in: CGRect(x: 0, y: 0, width: drawRect.width, height: drawRect.height))
        ctx.restoreGState()
    }

    // 4. En-tête supérieur : Badge + Titre + Instructions claires
    // Pill "MACCARE • UNIVERSAL MACOS INSTALLER"
    let topBadgeRect = CGRect(x: 245, y: 24, width: 230, height: 22)
    let topBadgePath = addRoundedRect(topBadgeRect, radius: 11)
    ctx.saveGState()
    ctx.addPath(topBadgePath)
    ctx.setFillColor(NSColor(calibratedRed: 0.55, green: 0.28, blue: 0.98, alpha: 0.18).cgColor)
    ctx.fillPath()
    ctx.addPath(topBadgePath)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.65, green: 0.45, blue: 1.0, alpha: 0.45).cgColor)
    ctx.setLineWidth(1.0)
    ctx.strokePath()
    ctx.restoreGState()

    drawCenteredText(
        "MACCARE  •  UNIVERSAL INSTALLER",
        centerX: 360,
        topY: 28,
        font: NSFont.systemFont(ofSize: 10.0, weight: .bold),
        color: NSColor(calibratedRed: 0.82, green: 0.72, blue: 1.0, alpha: 0.95),
        kern: 1.1
    )

    // Titre principal d'action
    drawCenteredText(
        "Drag MacCare to your Applications folder",
        centerX: 360,
        topY: 56,
        font: NSFont.systemFont(ofSize: 22.0, weight: .bold),
        color: NSColor(calibratedWhite: 0.98, alpha: 1.0),
        kern: -0.3
    )

    // Sous-titre bilingue explicatif
    drawCenteredText(
        "Glissez l'icône MacCare vers le dossier Applications pour installer l'application sur votre Mac",
        centerX: 360,
        topY: 86,
        font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
        color: NSColor(calibratedRed: 0.72, green: 0.75, blue: 0.88, alpha: 0.90)
    )

    // 5. Dessin des deux socles Glassmorphic (Gauche = MacCare.app, Droite = Applications)
    func drawDropCard(
        centerX: CGFloat,
        centerY: CGFloat,
        stepBadge: String,
        accentColor: NSColor,
        secondaryColor: NSColor,
        isTarget: Bool
    ) {
        let cardW: CGFloat = 188
        let cardH: CGFloat = 204
        let cardRect = CGRect(
            x: centerX - cardW / 2.0,
            y: centerY - cardH / 2.0 + 6,
            width: cardW,
            height: cardH
        )
        let cardPath = addRoundedRect(cardRect, radius: 28)

        // Ombre portée douce
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: 12),
            blur: 28,
            color: NSColor(calibratedWhite: 0.0, alpha: 0.45).cgColor
        )
        ctx.addPath(cardPath)
        ctx.setFillColor(NSColor(calibratedRed: 0.11, green: 0.10, blue: 0.20, alpha: 0.78).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Dégradé interne vitré
        ctx.saveGState()
        ctx.addPath(cardPath)
        ctx.clip()
        let cardGradColors = [
            accentColor.withAlphaComponent(0.16).cgColor,
            NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.19, alpha: 0.65).cgColor,
            secondaryColor.withAlphaComponent(0.10).cgColor
        ] as CFArray
        if let cardGrad = CGGradient(colorsSpace: colorSpace, colors: cardGradColors, locations: [0.0, 0.55, 1.0]) {
            ctx.drawLinearGradient(
                cardGrad,
                start: CGPoint(x: cardRect.minX, y: cardRect.minY),
                end: CGPoint(x: cardRect.maxX, y: cardRect.maxY),
                options: []
            )
        }
        ctx.restoreGState()

        // Bordure lumineuse (pleine + pointillée interne si cible)
        ctx.saveGState()
        ctx.addPath(cardPath)
        ctx.setStrokeColor(accentColor.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(1.6)
        ctx.strokePath()
        ctx.restoreGState()

        if isTarget {
            let innerRect = cardRect.insetBy(dx: 8, dy: 8)
            let innerPath = addRoundedRect(innerRect, radius: 21)
            ctx.saveGState()
            ctx.addPath(innerPath)
            ctx.setStrokeColor(secondaryColor.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(1.3)
            ctx.setLineDash(phase: 0, lengths: [6, 5])
            ctx.strokePath()
            ctx.restoreGState()
        }

        // Anneau orbital subtil derrière l'emplacement exact de l'icône Finder (centerY - 12)
        let iconCenter = CGPoint(x: centerX, y: centerY - 10)
        ctx.saveGState()
        let ringRect = CGRect(x: iconCenter.x - 58, y: iconCenter.y - 58, width: 116, height: 116)
        ctx.strokeEllipse(in: ringRect)
        ctx.setStrokeColor(accentColor.withAlphaComponent(0.22).cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokeEllipse(in: ringRect)
        ctx.restoreGState()

        // Pill d'étape en haut de la carte
        let pillW: CGFloat = 136
        let pillH: CGFloat = 22
        let pillRect = CGRect(x: centerX - pillW / 2.0, y: cardRect.minY - 11, width: pillW, height: pillH)
        let pillPath = addRoundedRect(pillRect, radius: 11)
        ctx.saveGState()
        ctx.addPath(pillPath)
        ctx.setFillColor(NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.18, alpha: 0.96).cgColor)
        ctx.fillPath()
        ctx.addPath(pillPath)
        ctx.setStrokeColor(accentColor.withAlphaComponent(0.70).cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokePath()
        ctx.restoreGState()

        drawCenteredText(
            stepBadge,
            centerX: centerX,
            topY: pillRect.minY + 4,
            font: NSFont.systemFont(ofSize: 9.5, weight: .bold),
            color: accentColor.blended(withFraction: 0.45, of: .white) ?? .white,
            kern: 0.8
        )
    }

    // Socle gauche : MacCare.app (icône placée à x=195, y=222)
    drawDropCard(
        centerX: 195,
        centerY: 232,
        stepBadge: "1 • APPLICATION",
        accentColor: NSColor(calibratedRed: 0.68, green: 0.32, blue: 1.0, alpha: 1.0),
        secondaryColor: NSColor(calibratedRed: 0.16, green: 0.85, blue: 1.0, alpha: 1.0),
        isTarget: false
    )

    // Socle droit : Applications (icône placée à x=525, y=222)
    drawDropCard(
        centerX: 525,
        centerY: 232,
        stepBadge: "2 • DROP HERE",
        accentColor: NSColor(calibratedRed: 0.16, green: 0.68, blue: 1.0, alpha: 1.0),
        secondaryColor: NSColor(calibratedRed: 0.20, green: 0.92, blue: 0.65, alpha: 1.0),
        isTarget: true
    )

    // 6. Connecteur central lumineux "DRAG & DROP" avec chevrons néon (entre x=298 et x=422)
    let arrowY: CGFloat = 228

    // Halo sous la flèche
    let arrowTrackRect = CGRect(x: 302, y: arrowY - 22, width: 116, height: 44)
    let arrowTrackPath = addRoundedRect(arrowTrackRect, radius: 22)
    ctx.saveGState()
    ctx.addPath(arrowTrackPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.24, alpha: 0.88).cgColor)
    ctx.fillPath()
    ctx.addPath(arrowTrackPath)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.28, green: 0.78, blue: 1.0, alpha: 0.45).cgColor)
    ctx.setLineWidth(1.2)
    ctx.strokePath()
    ctx.restoreGState()

    // Dessin de 3 chevrons progressifs lumineux + flèche principale
    let chevronXs: [(CGFloat, CGFloat)] = [
        (322, 0.35),
        (344, 0.60),
        (366, 0.85),
        (388, 1.00)
    ]
    for (cx, alpha) in chevronXs {
        ctx.saveGState()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx - 6, y: arrowY - 9))
        path.addLine(to: CGPoint(x: cx + 4, y: arrowY))
        path.addLine(to: CGPoint(x: cx - 6, y: arrowY + 9))
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.22, green: 0.88, blue: 1.0, alpha: alpha).cgColor)
        ctx.setLineWidth(3.0)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    drawCenteredText(
        "GLISSER / DRAG",
        centerX: 360,
        topY: arrowY + 30,
        font: NSFont.systemFont(ofSize: 9.5, weight: .bold),
        color: NSColor(calibratedRed: 0.56, green: 0.88, blue: 1.0, alpha: 0.90),
        kern: 1.0
    )

    // 7. Barre de pied de page (Footer) rassurante
    let footerRect = CGRect(x: 76, y: 392, width: 568, height: 38)
    let footerPath = addRoundedRect(footerRect, radius: 19)
    ctx.saveGState()
    ctx.addPath(footerPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.16, alpha: 0.85).cgColor)
    ctx.fillPath()
    ctx.addPath(footerPath)
    ctx.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.10).cgColor)
    ctx.setLineWidth(1.0)
    ctx.strokePath()
    ctx.restoreGState()

    drawCenteredText(
        "✓ Universal Binary (Apple Silicon M1–M4 & Intel)     •     ✓ 100% Local & Private     •     ✓ 6 Languages Included",
        centerX: 360,
        topY: 404,
        font: NSFont.systemFont(ofSize: 11.2, weight: .semibold),
        color: NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.94, alpha: 0.92)
    )

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/maccare-dmg-bg"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let path1x = "\(outDir)/background@1x.png"
let path2x = "\(outDir)/background@2x.png"

if let rep1x = drawDMGBackground(scale: 1.0),
   let png1x = rep1x.representation(using: .png, properties: [:]) {
    try png1x.write(to: URL(fileURLWithPath: path1x))
    print("Generated \(path1x)")
}

if let rep2x = drawDMGBackground(scale: 2.0),
   let png2x = rep2x.representation(using: .png, properties: [:]) {
    try png2x.write(to: URL(fileURLWithPath: path2x))
    print("Generated \(path2x)")
}

