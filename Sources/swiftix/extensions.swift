/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Dictionary {
    subscript(key: Key, setDefault def: Value) -> Value {
        mutating get {
            if let value = self[key] {
                return value
            } else {
                self[key] = def
                return def
            }
        }
    }
}
