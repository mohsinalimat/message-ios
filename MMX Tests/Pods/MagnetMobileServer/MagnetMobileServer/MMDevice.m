//
//  Device.m
//
//  File generated by Magnet Lang Tool 2.3.0 on Jun 3, 2015 8:44:20 AM
//  @See Also: http://developer.magnet.com
//
#import "MMDevice.h"

@implementation MMDevice

+ (NSDictionary *)attributeMappings {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
    }];
    [dictionary addEntriesFromDictionary:[super attributeMappings]];
    return dictionary;
}

+ (NSDictionary *)listAttributeTypes {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
    }];
    [dictionary addEntriesFromDictionary:[super listAttributeTypes]];
    return dictionary;
}

+ (NSDictionary *)mapAttributeTypes {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
    }];
    [dictionary addEntriesFromDictionary:[super mapAttributeTypes]];
    return dictionary;
}

+ (NSDictionary *)enumAttributeTypes {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
        @"deviceStatus" : MMDeviceStatusContainer.class,
        @"os" : MMOsTypeContainer.class,
        @"pushAuthority" : MMPushAuthorityTypeContainer.class,
    }];
    [dictionary addEntriesFromDictionary:[super enumAttributeTypes]];
    return dictionary;
}

+ (NSArray *)charAttributes {
    NSMutableArray *array = [NSMutableArray arrayWithArray:@[
    ]];
    [array addObjectsFromArray:[super charAttributes]];
    return array;
}

@end