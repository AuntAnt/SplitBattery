//
//  Dictionary+.swift
//  SplitBattery
//
//  Created by Anton Kuzmin on 01.10.2025.
//

extension Dictionary where Key == Part {
    func getFirst(part: SplitPart) -> Value? {
        return self.first(where: { (key, _) in key.type == part })?.value
    }
}
