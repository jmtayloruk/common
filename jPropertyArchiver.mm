//
//  jPropertyArchiver.mm
//
//  Created by Jonathan Taylor on 26/07/2019.
//
//

#import "jPropertyArchiver.h"
#import "GeometryObjects.h"
#import "objc/runtime.h"

const char *getPropertyType(objc_property_t property)
{
    const char *attributes = property_getAttributes(property);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    while ((attribute = strsep(&state, ",")) != NULL) {
        if (attribute[0] == 'T') {
            if (strlen(attribute) <= 4) {
                break;
            }
            return (const char *)[[NSData dataWithBytes:(attribute + 3) length:strlen(attribute) - 4] bytes];
        }
    }
    return "@";
}

bool propertyIsReadOnly(objc_property_t property)
{
    const char *attributes = property_getAttributes(property);
    NSArray *attributesArray = [[NSString stringWithUTF8String:attributes] componentsSeparatedByString:@","];
    return [attributesArray containsObject:@"R"];
}

NSMutableDictionary *ArchivePropertiesForObject(id object, NSArray *exclude)
{
    // Return a dictionary containing all the writeable properties on the object
    // (except for the ones we have been told to exclude, which are internal ones rather than
    //  ones that can sensibly be written externally and/or recreated at a later point from a .plist specification)
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([object class], &outCount);
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        NSString *propNameNS = [SWF:@"%s", propName];
        if (propName && !propertyIsReadOnly(property) && ![exclude containsObject:propNameNS])
        {
            // This looks like a property we should archive
//            const char *propType = getPropertyType(property);
//            const char *propAttr = property_getAttributes(property);
            id propObj = [object valueForKey:propNameNS];
//            printf("Archive %s, type %s, class %s\n", propName, propType, object_getClassName(propObj));
            if ([propObj isKindOfClass:[JPoint2 class]])
                propObj = NSStringFromPoint(((JPoint2 *)propObj).ns);
            else if ([propObj isKindOfClass:[JPoint3 class]])
            {
                // I have to do this one by hand!
                JPoint3 *p = (JPoint3 *)propObj;
                propObj = [SWF:@"{%f %f %f}", p.x, p.y, p.z];
            }
            else if ([propObj isKindOfClass:[JRect class]])
                propObj = NSStringFromRect(((JRect *)propObj).ns);
            
            // Add the object to the dictionary, but only if it's not nil.
            // We cannot add a nil object to the dictionary.
            // If a property is nil, then we just have to understand (when unarchiving)
            // that properties will default to nil/0/etc if not present in the dictionary.
            // Certainly, that seems like reasonable behaviour (and in most cases already the implicit default for an uninitialized property).
            if (propObj != nil)
            {
                CHECK([propObj isKindOfClass:[NSString class]] || [propObj isKindOfClass:[NSNumber class]]);
                [result setObject:propObj forKey:propNameNS];
            }
        }
    }
    free(properties);
    return result;
}

void UnarchivePropertiesForObject(id destObject, NSDictionary *properties, NSArray *exclude/*caller handles special processing*/)
{
    for (NSString *key in [properties allKeys])
    {
        if (![exclude containsObject:key])
        {
            id propObj = [properties valueForKey:key];
            // Identify cases where the property requires "translation", and do that.
            objc_property_t property = class_getProperty([destObject class], key.UTF8String);
            if (property == nil)
            {
                // Class does not implement this property
                printf("Ignoring unrecognised key %s\n", key.UTF8String);
            }
            else
            {
                const char *propType = getPropertyType(property);
                if (!strcmp(propType, "JPoint2"))
                    propObj = [JPoint2 pointWithNSPoint:NSPointFromString((NSString *)propObj)];
                else if (!strcmp(propType, "JPoint3"))
                {
                    // I have to do this one by hand!
                    double x, y, z;
                    ALWAYS_ASSERT([propObj isKindOfClass:[NSString class]]);
                    int numRead = sscanf(((NSString *)propObj).UTF8String, "{%lf %lf %lf}", &x, &y, &z);
                    ALWAYS_ASSERT(numRead == 3);
                    propObj = [JPoint3 pointWithCoord3:coord3(x, y, z)];
                }
                else if (!strcmp(propType, "JRect"))
                    propObj = [JRect rectWithNSRect:NSRectFromString((NSString *)propObj)];
                
                // Set the property
                [destObject setValue:propObj forKey:key];
            }
        }
    }
}
