//
//  CoreDataAttributeJSONCompatibility.swift
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 9/14/14.
//  Copyright (c) 2014 ColemanCDA. All rights reserved.
//

import Foundation
import CoreData

internal extension NSManagedObject {
    
    // MARK: - Convenience Methods
    
    func JSONCompatibleValueForAttribute(attributeName: String) -> AnyObject? {
        
        let attributeValue: AnyObject? = self.valueForKey(attributeName)
        
        if attributeValue != nil {
            
            return self.JSONCompatibleValueForAttributeValue(attributeValue!, forAttribute: attributeName)
        }
        
        return nil
    }
    
    func setJSONCompatibleValue(JSONCompatibleValue: AnyObject?, forAttribute attributeName: String) {
        
        let attributeValue: AnyObject? = self.attributeValueForJSONCompatibleValue(JSONCompatibleValue!, forAttribute: attributeName)
        
        self.setValue(attributeValue, forKey: attributeName)
    }
    
    func attributeValueForJSONCompatibleValue(JSONCompatibleValue: AnyObject, forAttribute attributeName: String) -> AnyObject? {
        
        return self.entity.attributeValueForJSONCompatibleValue(JSONCompatibleValue: JSONCompatibleValue, forAttribute: attributeName)
    }
    
    func JSONCompatibleValueForAttributeValue(attributeValue: AnyObject?, forAttribute attributeName: String) -> AnyObject? {
        
        return self.entity.JSONCompatibleValueForAttributeValue(attributeValue, forAttribute: attributeName)
    }
    
    // MARK: - Conversion Methods
    
    /** Get an array from a to-many relationship. */
    func arrayValueForToManyRelationship(relationship key: String) -> [NSManagedObject]? {
        
        // assert relationship exists
        assert(self.entity.relationshipsByName[key] as? NSRelationshipDescription != nil, "Relationship \(key) doesnt exist on \(self.entity.name)")
        
        // get relationship
        let relationship = self.entity.relationshipsByName[key] as NSRelationshipDescription
        
        // assert that relationship is to-many
        assert(relationship.toMany, "Relationship \(key) on \(self.entity.name) is not to-many")
        
        let value: AnyObject? = self.valueForKey(key)
        
        if value == nil {
            
            return nil
        }
        
        // ordered set
        if relationship.ordered {
            
            let orderedSet = value as NSOrderedSet
            
            return orderedSet.array as? [NSManagedObject]
        }
        
        // set
        let set = value as NSSet
        
        return set.allObjects  as? [NSManagedObject]
    }
    
    // MARK: - Validate
    
    func isValidConvertedValue(convertedValue: AnyObject, forAttribute attributeName: String) -> Bool {
        
        let attributeDescription = self.entity.attributesByName[attributeName] as? NSAttributeDescription
        
        if attributeDescription == nil {
            
            return false
        }
        
        switch attributeDescription!.attributeType {
            
        case NSAttributeType.UndefinedAttributeType, NSAttributeType.ObjectIDAttributeType:
            return false
            
        case NSAttributeType.Integer16AttributeType, NSAttributeType.Integer32AttributeType, NSAttributeType.Integer64AttributeType, NSAttributeType.DecimalAttributeType, NSAttributeType.DoubleAttributeType, NSAttributeType.FloatAttributeType, NSAttributeType.BooleanAttributeType :
            
            // try to cast as number
            let number = convertedValue as? NSNumber
            return (number != nil)
            
        case NSAttributeType.StringAttributeType:
            
            let string = convertedValue as? String
            return (string != nil)
            
        case NSAttributeType.DateAttributeType:
            
            let date = convertedValue as? NSDate
            return (date != nil)
            
        case NSAttributeType.BinaryDataAttributeType:
            
            let data = convertedValue as? NSData
            return (data != nil)
            
        // transformable value type
        case NSAttributeType.TransformableAttributeType:
            
            // get transformer
            let valueTransformerName = attributeDescription?.valueTransformerName
            
            // default transformer: NSKeyedUnarchiveFromDataTransformerName in reverse
            if valueTransformerName == nil {
                
                let transformer = NSValueTransformer(forName: NSKeyedUnarchiveFromDataTransformerName)
                
                // anything that conforms to NSCoding
                return (convertedValue as? NSCoding != nil)
            }
            
            // custom transformer
            let transformer = NSValueTransformer(forName: valueTransformerName!)
            
            // must convert to NSData
            let data = transformer!.transformedValue(convertedValue) as? NSData
            
            return (data != nil)
            
        }
    }
}

internal extension NSEntityDescription {
    
    // MARK: - Conversion Methods
    
    /** Converts a JSON-compatible value to a Core Data attribute value. */
    func JSONCompatibleValueForAttributeValue(attributeValue: AnyObject?, forAttribute attributeName: String) -> AnyObject? {
        
        let attributeDescription = self.attributesByName[attributeName] as? NSAttributeDescription
        
        if attributeDescription == nil {
            
            return nil
        }
        
        // give value based on attribute type...
        
        // if NSNull then just return NSNull     
        // nil attributes can be represented in JSON by NSNull
        if attributeValue as? NSNull != nil || attributeValue == nil {
            
            return NSNull()
        }
        
        if let attributeClassName = attributeDescription!.attributeValueClassName {
            
            switch attributeClassName {
                
                // strings and numbers are standard json data types
            case "NSString", "NSNumber":
                return attributeValue
                
            case "NSDate":
                let date = attributeValue as NSDate
                return date.ISO8601String()
                
            case "NSData":
                let data = attributeValue as NSData
                return data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.allZeros)
                
            default:
                return nil
            }
        }
        
        // transformable value type
        if attributeDescription?.attributeType == NSAttributeType.TransformableAttributeType {
            
            // get transformer
            let valueTransformerName = attributeDescription?.valueTransformerName
            
            // default transformer: NSKeyedUnarchiveFromDataTransformerName in reverse
            if valueTransformerName == nil {
                
                let transformer = NSValueTransformer(forName: NSKeyedUnarchiveFromDataTransformerName)
                
                // convert to data
                let data = transformer!.reverseTransformedValue(attributeValue) as NSData
                
                // convert to string (for JSON export)
                return data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.allZeros)
            }
            
            // custom transformer
            let transformer = NSValueTransformer(forName: valueTransformerName!)
            
            // convert to data
            let data = transformer!.transformedValue(attributeValue) as NSData
            
            // convert to string (for JSON export)
            return data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.allZeros)
        }
        
        return nil
    }
    
    /** Converts a Core Data attribute value to a JSON-compatible value. */
    func attributeValueForJSONCompatibleValue(JSONCompatibleValue jsonValue: AnyObject, forAttribute attributeName: String) -> AnyObject? {
        
        let attributeDescription = self.attributesByName[attributeName] as? NSAttributeDescription
        
        if attributeDescription == nil {
            
            return nil
        }
        
        // if value is NSNull
        if jsonValue as? NSNull != nil {
            
            return nil
        }
        
        if let attributeClassName = attributeDescription!.attributeValueClassName {
            
            switch attributeClassName {
                
                // strings and numbers are standard json data types
            case "NSString", "NSNumber":
                return jsonValue
                
            case "NSDate":
                let dateString = jsonValue as String
                return NSDate.dateWithISO8601String(dateString)
                
            case "NSData":
                let dataString = jsonValue as String
                return NSData(base64EncodedString: dataString, options: NSDataBase64DecodingOptions.allZeros)
                
            default:
                
                return nil
            }
        }
        
        // transformable value type
        if attributeDescription?.attributeType == NSAttributeType.TransformableAttributeType {
            
            let base64EncodedString = jsonValue as? String
            
            if base64EncodedString == nil {
                
                return nil
            }
            
            // get data from Base64 string
            let data = NSData(base64EncodedString: base64EncodedString!, options: NSDataBase64DecodingOptions.allZeros)
            
            if data == nil {
                
                return nil
            }
            
            // get transformer
            let valueTransformerName = attributeDescription?.valueTransformerName
            
            // default transformer: NSKeyedUnarchiveFromDataTransformerName in reverse
            if valueTransformerName == nil {
                
                let transformer = NSValueTransformer(forName: NSKeyedUnarchiveFromDataTransformerName)!
                
                // unarchive
                return transformer.transformedValue(data)
            }
            
            // custom transformer
            let transformer = NSValueTransformer(forName: valueTransformerName!)!
            
            // convert to original type
            return transformer.reverseTransformedValue(data)
        }
        
        return nil
    }
}

// MARK: - Private Extensions

private extension NSDate {
    
    class func ISO8601DateFormatter() -> NSDateFormatter {
        
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance : NSDateFormatter? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = NSDateFormatter()
            Static.instance?.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        }
        return Static.instance!
    }
    
    class func dateWithISO8601String(ISO8601String: String) -> NSDate? {
        
        return self.ISO8601DateFormatter().dateFromString(ISO8601String)
    }
    
    func ISO8601String() -> String {
        
        return NSDate.ISO8601DateFormatter().stringFromDate(self)
    }
}

