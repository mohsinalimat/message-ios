/*
 * Copyright (c) 2015 Magnet Systems, Inc.
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License. You
 * may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "MMXQueryChannelResponse.h"
#import "MMXChannelResponse.h"
#import "MMXChannelInfo.h"
#import "MMXChannel.h"

@implementation MMXQueryChannelResponse

+ (NSDictionary *)attributeMappings {
    NSDictionary *dictionary = @{
                                 };
    NSMutableDictionary *attributeMappings = [[super attributeMappings] mutableCopy];
    [attributeMappings addEntriesFromDictionary:dictionary];
    
    return attributeMappings;
}

+ (NSDictionary *)listAttributeTypes {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"channels" : MMXChannelInfo.class,
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

- (NSArray *)toMMXChannels {
    NSMutableArray *channels = [NSMutableArray new];
    for (MMXChannelInfo *channelInfo in self.channels) {
        NSDictionary *channelDictionary = @{
                                            @"ownerUserID" : channelInfo.userId,
                                            @"name" : channelInfo.name,
                                            @"privateChannel": @(channelInfo.userChannel),
                                            @"summary": channelInfo.description,
                                            @"publishPermissions": @(channelInfo.publishPermission)
                                            };
        MMXChannel *ch = [[MMXChannel alloc] initWithDictionary:channelDictionary error:nil];
        if (ch)
            [channels addObject:ch];
    }
    
    return channels;
}

@end
