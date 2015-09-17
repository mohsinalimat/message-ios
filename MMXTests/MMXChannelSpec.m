//
//  MMXChannelSpec.m
//  MMX
//
//  Created by Jason Ferguson on 8/26/15.
//  Copyright (c) 2015 Magnet Systems, Inc. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "MMX.h"
#import "MMXDeviceManager.h"
#import "MMXDeviceManager_Private.h"
#import "MMXUtils.h"

#define DEFAULT_TEST_TIMEOUT 10.0

SPEC_BEGIN(MMXChannelSpec)

describe(@"MMXMessage", ^{
	
	NSString *senderUsername = [NSString stringWithFormat:@"sender_%f", [[NSDate date] timeIntervalSince1970]];
	NSString *senderPassword = @"magnet";
	NSString *senderName = senderUsername;
	NSURLCredential *senderCredential = [NSURLCredential credentialWithUser:senderUsername
																   password:senderPassword
																persistence:NSURLCredentialPersistenceNone];
	
	NSString *receiverUsername = [NSString stringWithFormat:@"receiver_%f", [[NSDate date] timeIntervalSince1970]];
	NSString *receiverPassword = @"magnet";
	NSString *receiverName = receiverUsername;
	NSURLCredential *receiverCredential = [NSURLCredential credentialWithUser:receiverUsername
																	 password:receiverPassword
																  persistence:NSURLCredentialPersistenceNone];
	
	MMXUser *sender = [[MMXUser alloc] init];
	sender.username = senderUsername;
	sender.displayName = senderName;
	
	MMXUser *receiver = [[MMXUser alloc] init];
	receiver.username = receiverUsername;
	receiver.displayName = receiverName;
	
	NSString *receiverDeviceID = [[NSUUID UUID] UUIDString];
		
	beforeAll(^{
		[MMXLogger sharedLogger].level = MMXLoggerLevelVerbose;
		[[MMXLogger sharedLogger] startLogging];
		
		[MMX setupWithConfiguration:@"default"];
		[MMX enableIncomingMessages];
		
		__block BOOL _isSuccess = NO;
		
		[MMXUser logOutWithSuccess:^{
			_isSuccess = YES;
		} failure:^(NSError *error) {
			_isSuccess = NO;
		}];
		
		[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
	});
	
	context(@"when pre-registering the users", ^{
		
		it(@"should return success for sender", ^{
			
			// Create some users
			__block BOOL _isSuccess = NO;
			
			[sender registerWithCredential:senderCredential success:^{
				[MMXUser logInWithCredential:senderCredential success:^(MMXUser *user) {
					_isSuccess = YES;
				} failure:^(NSError *error) {
					_isSuccess = NO;
				}];
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});
		
		it(@"should return success for receiver", ^{
			
			// Create some users
			__block BOOL _isSuccess = NO;
			
			NSString *originalDeviceID = [MMXDeviceManager deviceUUID];
			
			[MMXDeviceManager stub:@selector(deviceUUID) andReturn:receiverDeviceID];
			
			[receiver registerWithCredential:receiverCredential success:^{
				[MMXUser logInWithCredential:receiverCredential success:^(MMXUser *user) {
					[MMXDeviceManager stub:@selector(deviceUUID) andReturn:originalDeviceID];
					_isSuccess = YES;
				} failure:^(NSError *error) {
					_isSuccess = NO;
				}];
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});
		
		afterEach(^{
			
			__block BOOL _isSuccess = NO;
			
			[MMXUser logOutWithSuccess:^{
				_isSuccess = YES;
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});
	});
	
	context(@"when creating a channel", ^{
		
		it(@"should return success if the channel is valid", ^{
			
			NSString *channelName = [NSString stringWithFormat:@"channelName_%f", [[NSDate date] timeIntervalSince1970]];
			NSString *channelSummary = [NSString stringWithFormat:@"channelSummary_%f", [[NSDate date] timeIntervalSince1970]];
			MMXChannel *channel = [MMXChannel channelWithName:channelName summary:channelSummary];
			
			__block BOOL _isSuccess = NO;
			
			[MMXUser logInWithCredential:senderCredential success:^(MMXUser *user) {
				[channel createWithSuccess:^{
					_isSuccess = YES;
				} failure:^(NSError *error) {
					_isSuccess = NO;
				}];
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});
		
		it(@"should return the information used to create it", ^{
			
			NSString *channelName = [NSString stringWithFormat:@"channelName_%f", [[NSDate date] timeIntervalSince1970]];
			NSString *channelSummary = [NSString stringWithFormat:@"channelSummary_%f", [[NSDate date] timeIntervalSince1970]];
			MMXChannel *channel = [MMXChannel channelWithName:channelName summary:channelSummary];
			channel.isPublic = YES;
			__block BOOL _isSuccess = NO;
			
			[MMXUser logInWithCredential:senderCredential success:^(MMXUser *user) {
				[channel createWithSuccess:^{
					[MMXChannel channelsStartingWith:channelName limit:10 success:^(int totalCount, NSArray *channels) {
						MMXChannel *returnedChannel = channels.count ? channels[0] : nil;
						[[returnedChannel.creationDate shouldNot] beNil];
						[[theValue(totalCount) should] equal:theValue(1)];
						[[returnedChannel shouldNot] beNil];
						[[theValue([channelSummary isEqualToString:returnedChannel.summary]) should] beYes];
						[[theValue([returnedChannel.ownerUsername isEqualToString:[MMXUser currentUser].username]) should] beYes];
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
		
		afterEach(^{
			
			__block BOOL _isSuccess = NO;
			
			[MMXUser logOutWithSuccess:^{
				_isSuccess = YES;
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});
	});
	
	context(@"when finding a channel by name", ^{
		it(@"should only return one valid channel", ^{
			__block BOOL _isSuccess = NO;
			[MMXUser logInWithCredential:senderCredential success:^(MMXUser *user) {
				[MMXChannel channelForChannelName:@"test_topic" success:^(MMXChannel *channel) {
					[[theValue([MMXUtils objectIsValidString:channel.name]) should] beYes];
					[[theValue([MMXUtils objectIsValidString:channel.summary]) should] beYes];
					[[theValue([MMXUtils objectIsValidString:channel.ownerUsername]) should] beYes];
					[[theValue(channel.isPublic) should] beYes];
					[[channel.creationDate shouldNot] beNil];
					_isSuccess = YES;
				} failure:^(NSError *error) {
					_isSuccess = NO;
				}];
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});
	});
	
	context(@"when sending an invite", ^{
		it(@"should fail if trying to send from a channel object that does not have the ownerUsername set", ^{
			__block BOOL _isSuccess = NO;
			[MMXUser logInWithCredential:senderCredential success:^(MMXUser *user) {
				MMXChannel *channel = [MMXChannel channelWithName:@"test_topic" summary:@"test_topic"];
				[channel inviteUser:[MMXUser currentUser] comments:@"No commment" success:^(MMXInvite *invite) {
					_isSuccess = NO;
				} failure:^(NSError *error) {
					_isSuccess = YES;
				}];
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});

		it(@"should succeed if trying to send from a channel object that is fully hydrated", ^{
			__block BOOL _isSuccess = NO;
			[MMXUser logInWithCredential:senderCredential success:^(MMXUser *user) {
				[MMXChannel channelForChannelName:@"test_topic" success:^(MMXChannel *channel) {
					[channel inviteUser:[MMXUser currentUser] comments:@"No commment" success:^(MMXInvite *invite) {
						[[invite shouldNot] beNil];
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
		
		afterEach(^{
			
			__block BOOL _isSuccess = NO;
			
			[MMXUser logOutWithSuccess:^{
				_isSuccess = YES;
			} failure:^(NSError *error) {
				_isSuccess = NO;
			}];
			
			[[expectFutureValue(theValue(_isSuccess)) shouldEventuallyBeforeTimingOutAfter(DEFAULT_TEST_TIMEOUT)] beYes];
		});

	});
	
});

SPEC_END