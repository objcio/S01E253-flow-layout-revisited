//
//  ContentView.swift
//  FlowLayout
//
//  Created by Chris Eidhof on 26.04.21.
//

import SwiftUI

struct SizeKey: PreferenceKey {
    static let defaultValue: [CGSize] = []
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

struct Identified<ID, A> {
    var id: ID
    var value: A
}

extension Identified: Equatable where ID: Equatable, A: Equatable { }

struct SizeKey2<ID>: PreferenceKey {
    static var defaultValue: [Identified<ID, CGSize>] { [] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

func layout(sizes: [CGSize], spacing: CGFloat = 10, containerWidth: CGFloat) -> [Range<Int>] {
    var result: [Range<Int>] = []
    var lineStart = sizes.startIndex
    while lineStart < sizes.endIndex {
        var currentX: CGFloat = 0
        var lineEnd = lineStart
        repeat {
            currentX += sizes[lineEnd].width + spacing
            lineEnd += 1
        } while lineEnd < sizes.endIndex && currentX + sizes[lineEnd].width < containerWidth
        result.append(lineStart..<lineEnd)
        lineStart = lineEnd
    }
    return result
}

struct MaxVisibleViewPreference: PreferenceKey {
    static let defaultValue: Int = 0
    static func reduce(value: inout Int, nextValue: () -> Int) {
        value = max(value, nextValue())
    }
}

struct FlowLayout<Element: Identifiable & Equatable, Cell: View>: View {
    var items: [Element]
    var cell: (Element) -> Cell
    @State private var sizes: [Int: CGSize] = [:]
    @State private var containerWidth: CGFloat = 0
    
    var measureStart: Int { sizes.keys.sorted().last ?? 0 }
    var measureEnd: Int { min(measureStart + 20, lastVisibleIndex) }
    @State var lastVisibleIndex = 0
    
    var hiddenMeasurements: some View {
        ZStack {
            ForEach(measureStart..<measureEnd, id: \.self) { ix in
                cell(items[ix])
                    .fixedSize()
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: SizeKey2.self, value: [Identified(id: ix, value: proxy.size)])
                    })
            }
        }.onPreferenceChange(SizeKey2<Int>.self, perform: { value in
            guard !value.isEmpty else { return }
            for pair in value {
                sizes[pair.id] = pair.value
            }
            print(value.first!.id, value.last!.id)
        }).id(measureStart..<measureEnd)
    }

    var body: some View {
        let sizeIndices = self.sizes.keys.sorted()
        if !sizeIndices.isEmpty {
            assert(sizeIndices[0] == 0)
            assert(sizeIndices.last == sizeIndices.count-1)
        }
        let sizes = sizeIndices.map { self.sizes[$0]! }
        var lines = layout(sizes: sizes, containerWidth: containerWidth)
        if lines.isEmpty {
            lines = items.indices.map { ix in
                ix..<ix+1
            }
        } else {
            let lastVisibleIndex = lines.last!.endIndex
            lines.append(contentsOf: (lastVisibleIndex..<items.endIndex).map { ix in
                ix..<ix+1
            })
        }
        return VStack(alignment: .leading, spacing: 0) {
            GeometryReader { proxy in
                Color.clear.preference(key: SizeKey.self, value: [proxy.size])
            }
            .frame(height: 0)
            .onPreferenceChange(SizeKey.self) { value in
                self.containerWidth = value[0].width
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.indices), id: \.self) { lineIndex in
                        
                        let line = lines[lineIndex]
                        HStack {
                            ForEach(Array(zip(line, items[line])), id: \.1.id) { (ix, item) in
                                cell(item)
                                    .fixedSize()
                                    .preference(key: MaxVisibleViewPreference.self, value: ix)
                            }
                        }
                    }
                }
                .onPreferenceChange(MaxVisibleViewPreference.self, perform: { value in
                    if value > lastVisibleIndex {
                        lastVisibleIndex = value
                    }
                    print("New last visible index: \(lastVisibleIndex)")
                })
                .id(containerWidth)
                .overlay(hiddenMeasurements.opacity(0))
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct Item: Identifiable, Hashable {
    var id = UUID()
    var value: String
}

struct ContentView: View {
    @State var items: [Item] = (1...1_000_000).map { "Item \($0) " + (Bool.random() ? "\n" : "")  + String(repeating: "x", count: Int.random(in: 0...10)) }.map { Item(value: $0) }

    var body: some View {
//        ScrollView {
            FlowLayout(items: items, cell: { item in
                Text(item.value)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
            })
//            .border(Color.red)
//        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
