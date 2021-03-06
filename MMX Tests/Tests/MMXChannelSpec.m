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


#import <Kiwi/Kiwi.h>
@import MagnetMax;
@import MMX;

typedef void(^Completion)(MMXChannel* channel);

@interface Tester : NSObject
+ (void)makeMMXChannel:(NSString*)name isPublic : (bool)isPublic completion : (Completion )completion;
@end

@implementation Tester

+ (void)makeMMXChannel:(NSString*) name isPublic : (bool)isPublic completion : (Completion )completion {
    [MMXChannel createWithName:name summary:name isPublic:isPublic publishPermissions:MMXPublishPermissionsAnyone success:^(MMXChannel * _Nonnull channel) {
        completion(channel);
    } failure:^(NSError * _Nonnull error) {
        if (error.code == 409) {
            [MMXChannel channelForName:name isPublic:isPublic success:^(MMXChannel * _Nonnull channel) {
                completion(channel);
            } failure:^(NSError * _Nonnull error) {
                NSLog(@"%@",error);
            }];
        }
    }];
}


@end


#define DEFAULT_TEST_TIMEOUT 10.0

SPEC_BEGIN(MMXChannelSpec)
describe(@"MMXChannel", ^{
    
    NSString *senderUsername = [NSString stringWithFormat:@"sender_%f", [[NSDate date] timeIntervalSince1970]];
    NSString *senderPassword = @"magnet";
    NSURLCredential *senderCredential = [NSURLCredential credentialWithUser:senderUsername
                                                                   password:senderPassword
                                                                persistence:NSURLCredentialPersistenceNone];
    
    MMUser *sender = [[MMUser alloc] init];
    sender.userName = senderUsername;
    sender.password = senderPassword;
    
    beforeAll(^{
        
        [MMXLogger sharedLogger].level = MMXLoggerLevelVerbose;
        [[MMXLogger sharedLogger] startLogging];
        NSString *filename = @"MagnetMax";
        NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:filename ofType:@"plist"];
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if (!exists) {
            //Try to fallover to mainBundle
            path = [[NSBundle mainBundle] pathForResource:filename ofType:@"plist"];
            
            exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
            if (!exists) {
                NSAssert(exists, @"You must include your MagnetMax.plist file in the project. You can download this file on the Settings page of the Magnet Message Web Interface");
            }
        }
        id <MMConfiguration> configuration = [[MMPropertyListConfiguration alloc] initWithContentsOfFile:path];
        [MagnetMax configure:configuration];
        
        __block BOOL _isSuccess = NO;
        
        [sender register:^(MMUser * _Nonnull user) {
            [MMUser login:senderCredential success:^{
                [MagnetMax initModule:[MMX sharedInstance] success:^{
                    [MMX start];
                    _isSuccess = YES;
                } failure:^(NSError * error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError * _Nonnull error) {
                _isSuccess = NO;
            }];
        } failure:^(NSError * _Nonnull error) {
            _isSuccess = NO;
        }];
        
        [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
    });
    
    context(@"when creating a channel", ^{
        
        it(@"should return success if the channel is valid", ^{
            
            NSString *channelName = [NSString stringWithFormat:@"channelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"channelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block BOOL _isSuccess = NO;
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:NO publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [[channel.name shouldNot] beNil];
                [[channel.summary shouldNot] beNil];
                [[channel.creationDate shouldNot] beNil];
                [[channel.ownerUserID shouldNot] beNil];
                _isSuccess = YES;
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should return the information used to create it", ^{
            
            NSString *channelName = [NSString stringWithFormat:@"channelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"channelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block BOOL _isSuccess = NO;
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:YES publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [MMXChannel channelsStartingWith:channelName limit:10 offset:0 success:^(int totalCount, NSArray *channels) {
                    MMXChannel *returnedChannel = channels.count ? channels[0] : nil;
                    [[returnedChannel.creationDate shouldNot] beNil];
                    [[theValue(totalCount) should] equal:theValue(1)];
                    [[returnedChannel shouldNot] beNil];
                    [[theValue([channelSummary isEqualToString:returnedChannel.summary]) should] beYes];
                    [[theValue([returnedChannel.ownerUserID isEqualToString:[MMUser currentUser].userID]) should] beYes];
                    _isSuccess = YES;
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should not have any tags set on it", ^{
            
            NSString *channelName = [NSString stringWithFormat:@"channelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"channelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block BOOL _isSuccess = NO;
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:YES publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [channel tagsWithSuccess:^(NSSet *tags) {
                    _isSuccess = YES;
                    [[expectFutureValue(theValue(tags.count)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beZero];
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    context(@"when finding a channel by name", ^{
        
        it(@"should succeed if created or exists.", ^{
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            
            NSString *channelName = @"test_topic";
            NSString *channelSummary = @"test_topic";
            NSSet *tagSet = [NSSet setWithObjects:@"test_topic_tag", nil];
            
            __block BOOL _isSuccess = NO;
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:YES publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [channel setTags:tagSet success:^{
                    [channel tagsWithSuccess:^(NSSet *tags2) {
                        [[expectFutureValue(theValue(tags2.count)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:theValue(tagSet.count)];
                        _isSuccess = YES;
                    } failure:^(NSError *error) {
                        _isSuccess = NO;
                    }];
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = error.code == 409;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should only return one valid channel", ^{
            __block BOOL _isSuccess = NO;
            [MMXChannel channelForName:@"test_topic" isPublic:YES success:^(MMXChannel *channel) {
                [[theValue([MMXUtils objectIsValidString:channel.name]) should] beYes];
                [[theValue([MMXUtils objectIsValidString:channel.summary]) should] beYes];
                [[theValue([MMXUtils objectIsValidString:channel.ownerUserID]) should] beNonNil];
                [[theValue(channel.isPublic) should] beYes];
                [[channel.creationDate shouldNot] beNil];
                _isSuccess = YES;
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    context(@"when creating a private channel", ^{
        it(@"should succeed if channel is created or exists.", ^{
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            
            NSString *channelName = @"test_topic_private";
            NSString *channelSummary = @"test_topic_private";
            
            __block BOOL _isSuccess = NO;
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:NO publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                _isSuccess = YES;
            } failure:^(NSError *error) {
                _isSuccess = error.code == 409;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    context(@"when setting tags on a channel", ^{
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        it(@"retain only those tags", ^{
            NSString *channelName = [NSString stringWithFormat:@"channelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"channelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block BOOL _isSuccess = NO;
            NSSet *tagSet = [NSSet setWithObjects:@"tag1",@"tag2", nil];
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:YES publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [channel setTags:tagSet success:^{
                    [channel tagsWithSuccess:^(NSSet *tags2) {
                        [[expectFutureValue(theValue(tags2.count)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:theValue(tagSet.count)];
                        _isSuccess = YES;
                    } failure:^(NSError *error) {
                        _isSuccess = NO;
                    }];
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
#pragma clang diagnostic pop
    });
    
    context(@"when searching by tags", ^{
        
        it(@"should only return one valid channel for the test tag", ^{
            __block BOOL _isSuccess = NO;
            [MMXChannel findByTags:[NSSet setWithObject:@"test_topic_tag"] limit:100 offset:0 success:^(int totalCount, NSArray *channels) {
                MMXChannel *returnedChannel = channels.count ? channels[0] : nil;
                [[returnedChannel.creationDate shouldNot] beNil];
                [[theValue(totalCount) should] equal:theValue(1)];
                [[returnedChannel shouldNot] beNil];
                [[theValue([MMXUtils objectIsValidString:returnedChannel.name]) should] beYes];
                [[theValue([MMXUtils objectIsValidString:returnedChannel.summary]) should] beYes];
                [[theValue([MMXUtils objectIsValidString:returnedChannel.ownerUserID]) should] beNonNil];
                [[theValue(returnedChannel.isPublic) should] beYes];
                [[returnedChannel.creationDate shouldNot] beNil];
                _isSuccess = YES;
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            //This test requires prepopulated data(a channel tagged with "test_topic_tag") to be on the server when the test is run
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    context(@"when sending an invite", ^{
        
        it(@"should succeed if trying to send from a channel object that is fully hydrated", ^{
            __block BOOL _isSuccess = NO;
            [MMXChannel channelForName:@"test_topic" isPublic:YES success:^(MMXChannel *channel) {
                [channel inviteUser:[MMUser currentUser] comments:@"No commment" success:^(MMXInvite *invite) {
                    [[invite shouldNot] beNil];
                    [[theValue([channel isEqual:invite.channel]) should] beYes];
                    [[theValue([[MMUser currentUser] isEqual:invite.sender]) should] beYes];
                    [[theValue([invite.comments isEqualToString:@""]) should] beNo];
                    _isSuccess = YES;
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            __block MMXInvite *receivedInvite;
            
            [[MMXDidReceiveChannelInviteNotification shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] bePostedEvaluatingBlock:^(NSNotification *notification){
                receivedInvite = notification.userInfo[MMXInviteKey];
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
            [[expectFutureValue(receivedInvite.timestamp) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNonNil];
            [[expectFutureValue(receivedInvite.comments) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:@"No commment"];
            [[expectFutureValue(receivedInvite.sender.userName) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:senderUsername];
            [[expectFutureValue(receivedInvite.channel) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNonNil];
            [[expectFutureValue(receivedInvite.channel.name) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:@"test_topic"];
            
            //This test requires prepopulated data(a channel named "test_topic") to be on the server when the test is run
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should succeed is channel is private", ^{
            __block BOOL _isSuccess = NO;
            [MMXChannel channelForName:@"test_topic_private" isPublic:NO success:^(MMXChannel *channel) {
                [channel inviteUser:[MMUser currentUser] comments:@"No commment" success:^(MMXInvite *invite) {
                    [[invite shouldNot] beNil];
                    [[theValue([channel isEqual:invite.channel]) should] beYes];
                    [[theValue([[MMUser currentUser] isEqual:invite.sender]) should] beYes];
                    [[theValue([invite.comments isEqualToString:@""]) should] beNo];
                    _isSuccess = YES;
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            __block MMXInvite *receivedInvite;
            
            [[MMXDidReceiveChannelInviteNotification shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] bePostedEvaluatingBlock:^(NSNotification *notification){
                receivedInvite = notification.userInfo[MMXInviteKey];
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
            [[expectFutureValue(receivedInvite.timestamp) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNonNil];
            [[expectFutureValue(receivedInvite.comments) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:@"No commment"];
            [[expectFutureValue(receivedInvite.sender.userName) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:senderUsername];
            [[expectFutureValue(receivedInvite.channel) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNonNil];
            [[expectFutureValue(receivedInvite.channel.name) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:@"test_topic_private"];
            
            //This test requires prepopulated data(a channel named "test_topic") to be on the server when the test is run
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    
    context(@"when publishing to a channel", ^{
        
        it(@"should deliver a valid MMXMessage if the user is subscribed", ^{
            
            NSString *channelName = [NSString stringWithFormat:@"publicChannelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"publicChannelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block MMXMessage *receivedMessage;
            __block BOOL _isSuccess = NO;
            
            NSDictionary *messageContent = @{@"Something1":@"Content1"};
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:YES publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [[expectFutureValue(theValue(channel.isSubscribed)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
                [channel publish:messageContent success:^(MMXMessage *message) {
                    _isSuccess = YES;
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[MMXDidReceiveMessageNotification shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] bePostedEvaluatingBlock:^(NSNotification *notification){
                receivedMessage = notification.userInfo[MMXMessageKey];
                NSLog(@"received message with messageID: %@", receivedMessage.messageID);
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
            [[expectFutureValue(receivedMessage.messageID) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNonNil];
            [[expectFutureValue(receivedMessage.recipients) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNil];
            [[expectFutureValue(receivedMessage.messageContent) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:messageContent];
            [[expectFutureValue(theValue(receivedMessage.messageType)) should] equal:theValue(MMXMessageTypeChannel)];
            [[expectFutureValue(receivedMessage.sender.userName) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:senderUsername];
            [[expectFutureValue(receivedMessage.channel) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNonNil];
            
            
            [[expectFutureValue(receivedMessage.channel.name.lowercaseString) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] equal:channelName.lowercaseString];
            
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should NOT deliver a MMXMessage if the user is not subscribed", ^{
            
            NSString *channelName = [NSString stringWithFormat:@"publicChannelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"publicChannelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block MMXMessage *receivedMessage;
            __block BOOL _isSuccess = NO;
            
            NSDictionary *messageContent = @{@"Something2":@"Content2"};
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:YES publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [channel unSubscribeWithSuccess:^{
                    [[expectFutureValue(theValue(channel.isSubscribed)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beNo];
                    [channel publish:messageContent success:^(MMXMessage *message) {
                        _isSuccess = YES;
                    } failure:^(NSError *error) {
                        _isSuccess = NO;
                    }];
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[MMXDidReceiveMessageNotification shouldNotEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT/2.0)] bePostedEvaluatingBlock:^(NSNotification *notification){
                receivedMessage = notification.userInfo[MMXMessageKey];
                NSLog(@"received message with messageID: %@", receivedMessage.messageID);
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    
    context(@"when getting all public channels", ^{
        it(@"should return more than one channel", ^{
            __block NSArray *_fetchedChannels = @[]; // Set should start empty
            __block int _totalCount = 0; // Start value at zero
            
            [MMXChannel allPublicChannelsWithLimit:100 offset:0 success:^(int totalCount, NSArray *channels) {
                _fetchedChannels = channels;
                _totalCount = totalCount;
            } failure:^(NSError * error) {
            }];
            
            // Assert
            [[expectFutureValue(_fetchedChannels) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] haveCountOfAtLeast:1];
            [[expectFutureValue(theValue(_totalCount)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beBetween:theValue(1) and:theValue(100)];
        });
        
        it(@"should have the same channel for offset 0 channel 1 as offset 1 channel 0", ^{
            __block BOOL _isSuccess = NO;
            
            [MMXChannel allPublicChannelsWithLimit:100 offset:0 success:^(int totalCount, NSArray *channels1) {
                MMXChannel *channelAtOffset0Position1 = channels1[1];
                [MMXChannel allPublicChannelsWithLimit:100 offset:1 success:^(int totalCount, NSArray *channels2) {
                    MMXChannel *channelAtOffset1Position0 = channels2[0];
                    [[theValue([channelAtOffset0Position1 isEqual:channelAtOffset1Position0]) should] beYes];
                    _isSuccess = YES;
                } failure:^(NSError * error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError * error) {
                _isSuccess = NO;
            }];
            
            // Assert
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    context(@"when getting all private channels", ^{
        it(@"should return more than one channel", ^{
            __block NSArray *_fetchedChannels = @[]; // Set should start empty
            __block int _totalCount = 0; // Start value at zero
            
            NSString *channelName = [NSString stringWithFormat:@"privateChannelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"privateChannelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            
            NSString *channelName2 = [NSString stringWithFormat:@"privateChannelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary2 = [NSString stringWithFormat:@"privateChannelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:NO publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [MMXChannel createWithName:channelName2 summary:channelSummary2 isPublic:NO publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                    [MMXChannel allPrivateChannelsWithLimit:100 offset:0 success:^(int totalCount, NSArray *channels) {
                        _fetchedChannels = channels;
                        _totalCount = totalCount;
                    } failure:^(NSError * error) {
                    }];
                } failure:^(NSError * error) {
                }];
            } failure:^(NSError * error) {
            }];
            
            // Assert
            [[expectFutureValue(_fetchedChannels) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] haveCountOfAtLeast:1];
            [[expectFutureValue(theValue(_totalCount)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beBetween:theValue(1) and:theValue(100)];
        });
        
        it(@"should have the same channel for offset 0 channel 1 as offset 1 channel 0", ^{
            __block BOOL _isSuccess = NO;
            
            [MMXChannel allPrivateChannelsWithLimit:100 offset:0 success:^(int totalCount, NSArray *channels1) {
                MMXChannel *channelAtOffset0Position1 = channels1[1];
                [MMXChannel allPrivateChannelsWithLimit:100 offset:1 success:^(int totalCount, NSArray *channels2) {
                    MMXChannel *channelAtOffset1Position0 = channels2[0];
                    [[theValue([channelAtOffset0Position1 isEqual:channelAtOffset1Position0]) should] beYes];
                    _isSuccess = YES;
                } failure:^(NSError * error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError * error) {
                _isSuccess = NO;
            }];
            
            // Assert
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    context(@"when fetching messages from a channel", ^{
        
        it(@"should return success if the fetch returns an empty array of message because no one has posted yet", ^{
            
            NSString *channelName = [NSString stringWithFormat:@"publicChannelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"publicChannelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block BOOL _isSuccess = NO;
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:NO publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [channel messagesBetweenStartDate:nil endDate:nil limit:100 offset:0 ascending:YES success:^(int totalCount, NSArray *messages) {
                    
                    [[theValue(totalCount == 0) should] beYes];
                    [[theValue(messages.count == 0) should] beYes];
                    _isSuccess = YES;
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should return success if the fetch returns valid messages(Public Channel)", ^{
            
            NSString *channelName = [NSString stringWithFormat:@"publicChannelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"publicChannelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            __block BOOL _isSuccess = NO;
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:NO publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [channel publish:@{@"key":@"value"} success:^(MMXMessage *message) {
                    [channel messagesBetweenStartDate:nil endDate:nil limit:100 offset:0 ascending:YES success:^(int totalCount, NSArray *messages) {
                        MMXMessage *msg = messages[0];
                        [[msg should] beNonNil];
                        [[theValue(totalCount > 0) should] beYes];
                        _isSuccess = YES;
                    } failure:^(NSError *error) {
                        _isSuccess = NO;
                    }];
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should return success if the fetch returns valid messages(Private Channel)", ^{
            __block BOOL _isSuccess = NO;
            
            NSString *channelName = [NSString stringWithFormat:@"privateChannelName_%f", [[NSDate date] timeIntervalSince1970]];
            NSString *channelSummary = [NSString stringWithFormat:@"privateChannelSummary_%f", [[NSDate date] timeIntervalSince1970]];
            
            [MMXChannel createWithName:channelName summary:channelSummary isPublic:NO publishPermissions:MMXPublishPermissionsSubscribers success:^(MMXChannel *channel) {
                [channel publish:@{@"key":@"value"} success:^(MMXMessage *message) {
                    [channel messagesBetweenStartDate:nil endDate:nil limit:100 offset:0 ascending:YES success:^(int totalCount, NSArray *messages) {
                        MMXMessage *msg = messages[0];
                        [[msg should] beNonNil];
                        [[theValue(totalCount > 0) should] beYes];
                        _isSuccess = YES;
                    } failure:^(NSError *error) {
                        _isSuccess = NO;
                    }];
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    
    
    context(@"when getting subscribers to a channel", ^{
        it(@"should return at least one user", ^{
            __block BOOL _isSuccess = NO;
            
            [MMXChannel subscribedChannelsWithSuccess:^(NSArray *channels) {
                MMXChannel *myChannel = channels.firstObject;
                [[myChannel shouldNot] beNil];
                [myChannel subscribersWithLimit:100 offset:0 success:^(int totalCount, NSArray *subscribers) {
                    MMUser *usr = subscribers[0];
                    [[usr should] beNonNil];
                    [[theValue(totalCount > 0) should] beYes];
                    _isSuccess = YES;
                } failure:^(NSError *error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            
            // Assert
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    
    NSString *addedRemoveChannelName = [@"chan_test_" stringByAppendingFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    __block MMXChannel *addedRemoveChannel = nil;
    context(@"when adding subscribers to a channel", ^{
        it(@"should create channel", ^{
            __block BOOL _isSuccess = YES;
            [MMXChannel createWithName:addedRemoveChannelName
                               summary:addedRemoveChannelName
                              isPublic:YES
                    publishPermissions:MMXPublishPermissionsOwnerOnly
                               success:^(MMXChannel *channel) {
                                   addedRemoveChannel = channel;
                               } failure:^(NSError * error) {
                                   if (error.code != 409) {
                                       _isSuccess = NO;
                                   }
                               }];
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should create users", ^{
            __block BOOL _isSuccess = YES;
            
            MMUser *sender = [[MMUser alloc] init];
            sender.userName = @"testuser123";
            sender.password = @"testuser123";
            MMUser *sender2 = [[MMUser alloc] init];
            sender2.userName = @"testuser1234";
            sender2.password = @"testuser1234";
            MMUser *sender3 = [[MMUser alloc] init];
            sender3.userName = @"testuser12345";
            sender3.password = @"testuser12345";
            
            NSArray *users = @[sender,sender2,sender3];
            for(MMUser *mmuser in users) {
                [mmuser register:^(MMUser *user) {
                } failure:^(NSError * error) {
                    if (error.code != 409) {
                        _isSuccess = NO;
                    }
                }];
            }
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
        it(@"should return success", ^{
            __block BOOL _isSuccess = NO;
            [MMXChannel channelForName:addedRemoveChannelName isPublic:YES success:^(MMXChannel *channel) {
                MMXChannel *myChannel = channel;
                NSInteger expectedNumberOfUsers = 4;
                [MMUser usersWithUserNames:@[@"testuser123",@"testuser1234",@"testuser12345"] success:^(NSArray<MMUser *> *users) {
                    MMUser *invalidUser = [MMUser new];
                    invalidUser.userName = @"dsaffsdd";
                    invalidUser.userID = @"dadasdsd";
                    NSMutableArray *usersWithInvalidUser = [NSMutableArray new];
                    [usersWithInvalidUser addObject:invalidUser];
                    [usersWithInvalidUser addObjectsFromArray:users];
                    [myChannel addSubscribers:usersWithInvalidUser
                                      success:^(NSSet<MMUser *> *invalidUsers) {
                                          [myChannel subscribersWithLimit:100
                                                                   offset:0
                                                                  success:^(int totalCount, NSArray<MMUser *> *subscribers) {
                                                                      if (invalidUsers.count == 1 && totalCount == expectedNumberOfUsers) {
                                                                          _isSuccess = YES;
                                                                      }
                                                                  } failure:^(NSError *error) {
                                                                      _isSuccess = NO;
                                                                  }];
                                      } failure:^(NSError *error) {
                                          _isSuccess = NO;
                                      }];
                } failure:^(NSError * error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            // Assert
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
    });
    
    context(@"when removing subscribers from a channel", ^{
        it(@"should return success", ^{
            __block BOOL _isSuccess = NO;
            [MMXChannel channelForName:addedRemoveChannelName isPublic:YES success:^(MMXChannel *channel) {
                MMXChannel *myChannel = channel;
                NSInteger expectedNumberOfUsers = 3;
                [MMUser usersWithUserNames:@[@"testuser123"] success:^(NSArray<MMUser *> *users) {
                    
                    [myChannel removeSubscribers:users
                                         success:^(NSSet<MMUser *> *invalidUsers) {
                                             [myChannel subscribersWithLimit:100
                                                                      offset:0
                                                                     success:^(int totalCount, NSArray<MMUser *> *subscribers) {
                                                                         if (totalCount == expectedNumberOfUsers) {
                                                                             _isSuccess = YES;
                                                                         }
                                                                     } failure:^(NSError *error) {
                                                                         _isSuccess = NO;
                                                                     }];
                                         } failure:^(NSError *error) {
                                             _isSuccess = NO;
                                         }];
                    
                } failure:^(NSError * error) {
                    _isSuccess = NO;
                }];
            } failure:^(NSError *error) {
                _isSuccess = NO;
            }];
            // Assert
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
        
    });
    
    context(@"when finding channes by subscribers", ^{
        it(@"should return success for ANY Match", ^{
            __block BOOL _isSuccess = NO;
            
            [MMUser usersWithUserNames:@[@"testuser12345",@"testuser1234"] success:^(NSArray<MMUser *> *users) {
                
                [MMXChannel findChannelsBySubscribers:users
                                            matchType:MMXMatchTypeSUBSET_MATCH
                                              success:^(NSArray<MMXChannel *> * channels) {
                                                  _isSuccess = [channels.firstObject.name isEqualToString:addedRemoveChannelName] &&
                                                  [channels.firstObject isKindOfClass:[MMXChannel class]];
                                              } failure:^(NSError * error) {
                                                  _isSuccess = NO;
                                              }];
            } failure:^(NSError * error) {
                _isSuccess = NO;
            }];
            // Assert
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
        });
    });
    
    context(@"when requesting summaries", ^{
        it(@"should return success", ^{
            
            __block BOOL _isSuccess = NO;
            
            [addedRemoveChannel publish:@{@"hello" : @"hello"} success:^(MMXMessage * _Nonnull message) {
                _isSuccess = YES;
            } failure:^(NSError * _Nonnull error) {
                _isSuccess = NO;
            }];
            
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(200)] beYes];
            
            [MMXChannel channelDetails:@[addedRemoveChannel]
                      numberOfMessages:10
                    numberOfSubcribers:10
                               success:^(NSArray <MMXChannelDetailResponse *> *detailsForChannels) {
                                   _isSuccess = YES && detailsForChannels.firstObject.messages.count > 0;
                               } failure:^(NSError *error) {
                                   _isSuccess = NO;
                               }];
            // Assert
            [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(200)] beYes];
        });
    });
    
    afterAll(^{
        __block BOOL _isSuccess = NO;
        
        [MMUser logout:^{
            _isSuccess = YES;
        } failure:^(NSError * _Nonnull error) {
            _isSuccess = NO;
        }];
        
        [[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(100)] beYes];
    });
    
});


SPEC_END

