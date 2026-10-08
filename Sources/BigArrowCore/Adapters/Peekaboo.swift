import CoreGraphics
import Foundation

/// Reads targets out of Peekaboo JSON. No build-time dependency on Peekaboo.
/// `see --json` and `window list --json` report `bounds` in global top-left points
/// (Peekaboo 4.9.0), which is exactly this tool's input space.
public enum PeekabooAdapter {
    public static let minimumVersionNote =
        "this Peekaboo snapshot has no 'bounds' (Peekaboo 3.x); upgrade to Peekaboo 4.9.0 or newer and run 'peekaboo see --json' again"

    /// `--peekaboo B3` against a `peekaboo see --json` snapshot.
    public static func element(id: String, snapshot: Data) throws -> ResolvedTarget {
        let elements = try array(named: "ui_elements", in: snapshot, command: "peekaboo see --json")
        guard let element = elements.first(where: { ($0["id"] as? String)?.lowercased() == id.lowercased() }) else {
            let ids = elements.compactMap { $0["id"] as? String }.prefix(40).joined(separator: ", ")
            throw BigArrowError.unresolvable("no element '\(id)' in the Peekaboo snapshot, ids: \(ids)")
        }
        let rect = try bounds(of: element)
        let label = [element["label"], element["title"]].compactMap { $0 as? String }.first { !$0.isEmpty }
        var detail = ["id": id]
        detail["label"] = label
        detail["role"] = element["role"] as? String
        return ResolvedTarget(shape: .rect(rect), source: "peekaboo", detail: detail)
    }

    /// `--peekaboo-window 0` against a `peekaboo window list --json` result.
    public static func window(index: Int, list: Data) throws -> ResolvedTarget {
        let windows = try array(named: "windows", in: list, command: "peekaboo window list --app X --json")
        let match = windows.first { ($0["window_index"] as? Int) == index }
        guard let window = match else {
            throw BigArrowError.unresolvable("no window with window_index \(index), the list has \(windows.count)")
        }
        var detail = ["windowIndex": String(index)]
        detail["title"] = window["window_title"] as? String
        return ResolvedTarget(shape: .rect(try bounds(of: window)), source: "peekaboo-window", detail: detail)
    }

    /// Peekaboo's CLI wraps results in `{success, data: {...}}`; its MCP tools return the bare object.
    static func array(named key: String, in json: Data, command: String) throws -> [[String: Any]] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: json)
        } catch {
            throw BigArrowError.badInput("the Peekaboo input is not JSON, create it with '\(command)'")
        }
        let root = object as? [String: Any]
        let container = (root?["data"] as? [String: Any]) ?? root
        guard let items = container?[key] as? [[String: Any]] else {
            throw BigArrowError.badInput("the Peekaboo JSON has no '\(key)' array, create it with '\(command)'")
        }
        return items
    }

    static func bounds(of item: [String: Any]) throws -> CGRect {
        guard let bounds = item["bounds"] as? [String: Any] else {
            throw BigArrowError.badInput(minimumVersionNote)
        }
        let values = ["x", "y", "width", "height"].compactMap { (bounds[$0] as? NSNumber)?.doubleValue }
        guard values.count == 4, values[2] > 0, values[3] > 0 else {
            throw BigArrowError.badInput("Peekaboo bounds are incomplete: \(bounds)")
        }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }
}
