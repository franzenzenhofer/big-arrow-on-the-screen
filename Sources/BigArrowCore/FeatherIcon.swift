import CoreGraphics

/// Icons from Feather (https://feathericons.com, MIT, Copyright (c) 2013-2023 Cole Bemis; licence
/// in THIRD_PARTY_NOTICES.md). The inner SVG of `feather-icons@4.29.2` `dist/icons/<name>.svg`,
/// verbatim: a 24 x 24 viewBox, stroked 2 units wide with round caps and joins, never filled.
public enum FeatherIcon: String, CaseIterable, Sendable {
    case copy
    case check

    public static let viewBox: CGFloat = 24
    public static let strokeWidth: CGFloat = 2

    public var svg: String {
        switch self {
        case .copy:
            #"<rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>"#
                + #"<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>"#
        case .check:
            #"<polyline points="20 6 9 17 4 12"></polyline>"#
        }
    }

    /// The outline in viewBox units, y down as in SVG. The source is fixed, so a failure is a bug here.
    public var path: CGPath {
        do {
            return try SVGPath.icon(svg)
        } catch {
            preconditionFailure("Feather icon '\(rawValue)' does not parse: \(error)")
        }
    }
}
