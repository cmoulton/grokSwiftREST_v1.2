//
//  ResponseJSONObjectSerializable.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-04-14.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

public protocol ResponseJSONObjectSerializable {
  init?(json: SwiftyJSON.JSON)
}
