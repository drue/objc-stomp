STOMP client for Objective-C
============================

This is a simple STOMP client based on [Stefan Saasen's version](https://github.com/juretta/objc-stomp) of an initial implementation (StompService) from Scott Raymond <sco@scottraymond.net> (see [http://gist.github.com/72935](http://gist.github.com/72935))
* and AsynSocket: [http://code.google.com/p/cocoaasyncsocket/](http://code.google.com/p/cocoaasyncsocket/)

This version differs in that it has been changed to support binary message bodies using the content-length header and an NSData interface.  It no longer supports messages with bodies that do not have a content length header.  The broker I'm using always sends content-length.

This repo also has an Xcode project with an ios static lib target, plus cocoasyncsocket as a git submodule.

Documentation
-------------

[http://dev.coravy.com/wiki/display/OpenSource/Stomp+client+for+Objective-C](http://dev.coravy.com/wiki/display/OpenSource/Stomp+client+for+Objective-C)


Usage
-----

Add AsynSocket.{h,m} and CRVStompClient.{h,m} to your project.

MyExample.h

	#import <Foundation/Foundation.h>
	
	@class CRVStompClient;
	@protocol CRVStompClientDelegate;


	@interface MyExample : NSObject<CRVStompClientDelegate> {
    	@private
		CRVStompClient *service;
	}
	@property(nonatomic, retain) CRVStompClient *service;

	@end


In MyExample.m

	#define kUsername	@"USERNAME"
	#define kPassword	@"PASS"
	#define kQueueName	@"/topic/systemMessagesTopic"

	[...]

	-(void) aMethod {
		CRVStompClient *s = [[CRVStompClient alloc] 
				initWithHost:@"localhost" 
						port:61613 
						login:kUsername
					passcode:kQueueName
					delegate:self];
		[s connect];
	

		NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: 	
				@"client", @"ack", 
				@"true", @"activemq.dispatchAsync",
				@"1", @"activemq.prefetchSize", nil];
		[s subscribeToDestination:kQueueName withHeader: headers];
	
		[self setService: s];
		[s release];
	}
	
	#pragma mark CRVStompClientDelegate
	- (void)stompClientDidConnect:(CRVStompClient *)stompService {
			NSLog(@"stompServiceDidConnect");
	}

	- (void)stompClient:(CRVStompClient *)stompService messageReceived:(NSData *)data withHeader:(NSDictionary *)messageHeader {
		NSLog(@"gotMessage body: %@, header: %@", data, messageHeader);
		NSLog(@"Message ID: %@", [messageHeader valueForKey:@"message-id"]);
		// If we have successfully received the message ackknowledge it.
		[stompService ack: [messageHeader valueForKey:@"message-id"]];
	}
	
	- (void)dealloc {
		[service unsubscribeFromDestination: kQueueName];
		[service release];
		[super dealloc];
	}
	
