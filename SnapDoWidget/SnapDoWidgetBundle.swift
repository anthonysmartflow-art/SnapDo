//
//  SnapDoWidgetBundle.swift
//  SnapDoWidget
//
//  Created by Anthony Rosenberger on 9/11/26.
//

import WidgetKit
import SwiftUI

@main
struct SnapDoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapDoWidget()
        SnapDoWidgetControl()
    }
}
