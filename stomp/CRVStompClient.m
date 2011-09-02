//
//  CRVStompClient.h
//  Objc-Stomp
//
//
//  Implements the Stomp Protocol v1.0
//  See: http://stomp.codehaus.org/Protocol
// 
//  Requires the AsyncSocket library
//  See: http://code.google.com/p/cocoaasyncsocket/
//
//  See: LICENSE
//	Stefan Saasen <stefan@coravy.com>
//  Andrew Loewenstern <drue@github>
//  Based on StompService.{h,m} by Scott Raymond <sco@scottraymond.net>.
#import "CRVStompClient.h"

#define kStompDefaultPort			61613
#define kDefaultTimeout				5	//


// ============= http://stomp.codehaus.org/Protocol =============
#define kCommandConnect				@"CONNECT"
#define kCommandSend				@"SEND"
#define kCommandSubscribe			@"SUBSCRIBE"
#define kCommandUnsubscribe			@"UNSUBSCRIBE"
#define kCommandBegin				@"BEGIN"
#define kCommandCommit				@"COMMIT"
#define kCommandAbort				@"ABORT"
#define kCommandAck					@"ACK"
#define kCommandDisconnect			@"DISCONNECT"
#define	kControlChar				"\0"

#define kAckClient					@"client"
#define kAckAuto					@"auto"

#define kResponseHeaderSession		@"session"
#define kResponseHeaderReceiptId	@"receipt-id"
#define kResponseHeaderErrorMessage @"message"

#define kResponseFrameConnected		@"CONNECTED"
#define kResponseFrameMessage		@"MESSAGE"
#define kResponseFrameReceipt		@"RECEIPT"
#define kResponseFrameError			@"ERROR"
// ============= http://stomp.codehaus.org/Protocol =============

#define CRV_RELEASE_SAFELY(__POINTER) { [__POINTER release]; __POINTER = nil; }

@interface CRVStompClient()
@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, retain) AsyncSocket *socket;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *passcode;
@property (nonatomic, copy) NSString *sessionId;
@end

@interface CRVStompClient(PrivateMethods)
- (void) sendFrame:(NSString *) command withHeader:(NSDictionary *) header andBody:(NSData *) body;
- (void) sendFrame:(NSString *) command;
- (void) readHeader;
- (void) readBody:(NSUInteger)length;
@end

@implementation CRVStompClient

@synthesize delegate;
@synthesize socket, host, port, login, passcode, sessionId;
@synthesize curHeaders, curCommand;

- (id)initWithHost:(NSString *)theHost 
			  port:(NSUInteger)thePort 
		  delegate:(id<CRVStompClientDelegate>)theDelegate
	   autoconnect:(BOOL) autoconnect {
	if(self == [self initWithHost:theHost port:thePort login:nil passcode:nil delegate:theDelegate autoconnect: NO]) {
		anonymous = YES;
	}
	return self;
}

- (id)initWithHost:(NSString *)theHost 
			  port:(NSUInteger)thePort 
			 login:(NSString *)theLogin 
		  passcode:(NSString *)thePasscode 
		  delegate:(id<CRVStompClientDelegate>)theDelegate {
	return [self initWithHost:theHost port:thePort login:theLogin passcode:thePasscode delegate:theDelegate autoconnect: NO];
}

- (id)initWithHost:(NSString *)theHost 
			  port:(NSUInteger)thePort 
			 login:(NSString *)theLogin 
		  passcode:(NSString *)thePasscode 
		  delegate:(id<CRVStompClientDelegate>)theDelegate
	   autoconnect:(BOOL) autoconnect {
	if(self = [super init]) {
		inHeaders = YES;
		anonymous = NO;
		doAutoconnect = autoconnect;
        
		AsyncSocket *theSocket = [[AsyncSocket alloc] initWithDelegate:self];
		[self setSocket: theSocket];
		[theSocket release];
		
		[self setDelegate:theDelegate];
		[self setHost: theHost];
		[self setPort: thePort];
		[self setLogin: theLogin];
		[self setPasscode: thePasscode];
		
		NSError *err;
		if(![self.socket connectToHost:self.host onPort:self.port error:&err]) {
			NSLog(@"StompService error: %@", err);
		}
	}
	return self;
}

#pragma mark -
#pragma mark Public methods
- (void)connect {
	if(anonymous) {
		[self sendFrame:kCommandConnect];
	} else {
		NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: [self login], @"login", [self passcode], @"passcode", nil];
		[self sendFrame:kCommandConnect withHeader:headers andBody: nil];
	}
	[self readHeader];
}

- (void)sendMessage:(NSString *)theMessage toDestination:(NSString *)destination {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: destination, @"destination", nil];
    [self sendFrame:kCommandSend withHeader:headers andBody:[theMessage dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)sendMessage:(NSString *)theMessage toDestination:(NSString *)destination withHeader:(NSDictionary *)header 
{
	NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:header];
    [headers setObject: destination forKey: @"destination"];
    [self sendFrame:kCommandSend withHeader:headers andBody:[theMessage dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)sendData:(NSData *)data toDestination:(NSString *)destination {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: destination, @"destination", nil];
    [self sendFrame:kCommandSend withHeader:headers andBody:data];
}

- (void)sendData:(NSData *)data toDestination:(NSString *)destination withHeader:(NSDictionary *)header 
{
	NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:header];
    [headers setObject: destination forKey: @"destination"];
    [self sendFrame:kCommandSend withHeader:headers andBody:data];
}


- (void)subscribeToDestination:(NSString *)destination {
	[self subscribeToDestination:destination withAck: CRVStompAckModeAuto];
}

- (void)subscribeToDestination:(NSString *)destination withAck:(CRVStompAckMode) ackMode {
	NSString *ack;
	switch (ackMode) {
		case CRVStompAckModeClient:
			ack = kAckClient;
			break;
		default:
			ack = kAckAuto;
			break;
	}
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: destination, @"destination", ack, @"ack", nil];
    [self sendFrame:kCommandSubscribe withHeader:headers andBody:nil];
}

- (void)subscribeToDestination:(NSString *)destination withHeader:(NSDictionary *) header {
	NSMutableDictionary *headers = [[NSMutableDictionary alloc] initWithDictionary:header];
	[headers setObject:destination forKey:@"destination"];
    [self sendFrame:kCommandSubscribe withHeader:headers andBody:nil];
	[headers release];
}

- (void)unsubscribeFromDestination:(NSString *)destination {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: destination, @"destination", nil];
    [self sendFrame:kCommandUnsubscribe withHeader:headers andBody:nil];
}

-(void)begin:(NSString *)transactionId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: transactionId, @"transaction", nil];
    [self sendFrame:kCommandBegin withHeader:headers andBody:nil];
}

- (void)commit:(NSString *)transactionId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: transactionId, @"transaction", nil];
    [self sendFrame:kCommandCommit withHeader:headers andBody:nil];
}

- (void)abort:(NSString *)transactionId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: transactionId, @"transaction", nil];
    [self sendFrame:kCommandAbort withHeader:headers andBody:nil];
}

- (void)ack:(NSString *)messageId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: messageId, @"message-id", nil];
    [self sendFrame:kCommandAck withHeader:headers andBody:nil];
}

- (void)disconnect {
	[self sendFrame:kCommandDisconnect];
	[[self socket] disconnectAfterReadingAndWriting];
}


#pragma mark -
#pragma mark PrivateMethods
- (void) sendFrame:(NSString *) command withHeader:(NSDictionary *) header andBody:(NSData *) body {
    NSMutableString *frameString = [NSMutableString stringWithString: [command stringByAppendingString:@"\n"]];
	for (id key in header) {
		[frameString appendString:key];
		[frameString appendString:@":"];
		[frameString appendString:[header objectForKey:key]];
		[frameString appendString:@"\n"];
	}
	if (body) {
        [frameString appendFormat:@"content-length: %d\n\n", [body length]];
	}
    else
        [frameString appendString:@"\n"];
    
    NSData *frameHeader = [frameString dataUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *frame = [NSMutableData data];
    
    [frame appendData:frameHeader];
    if(body)
        [frame appendData:body];
    [frame appendBytes:kControlChar length:1];
	[[self socket] writeData:frame withTimeout:kDefaultTimeout tag:123];
}

- (void) sendFrame:(NSString *) command {
	[self sendFrame:command withHeader:nil andBody:nil];
}

- (void)receiveFrame:(NSString *)command headers:(NSDictionary *)headers body:(NSData *)body {
	//NSLog(@"receiveCommand '%@' [%@], @%", command, headers, body);
	
	// Connected
	if([kResponseFrameConnected isEqual:command]) {
		if([[self delegate] respondsToSelector:@selector(stompClientDidConnect:)]) {
			[[self delegate] stompClientDidConnect:self];
		}
		
		// store session-id
		NSString *sessId = [headers valueForKey:kResponseHeaderSession];
		[self setSessionId: sessId];
        
        // Response 
	} else if([kResponseFrameMessage isEqual:command]) {
		[[self delegate] stompClient:self messageReceived:body withHeader:headers];
		
        // Receipt
	} else if([kResponseFrameReceipt isEqual:command]) {		
		if([[self delegate] respondsToSelector:@selector(serverDidSendReceipt:withReceiptId:)]) {
			NSString *receiptId = [headers valueForKey:kResponseHeaderReceiptId];
			[[self delegate] serverDidSendReceipt:self withReceiptId: receiptId];
		}	
        
        // Error
	} else if([kResponseFrameError isEqual:command]) {
		if([[self delegate] respondsToSelector:@selector(serverDidSendError:withErrorMessage:detailedErrorMessage:)]) {
			NSString *msg = [headers valueForKey:kResponseHeaderErrorMessage];
			[[self delegate] serverDidSendError:self withErrorMessage: msg detailedErrorMessage: [[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] autorelease]];
		}		
	}
}

- (void)readHeader {
    inHeaders = YES;
	[[self socket] readDataToData:[NSData dataWithBytes:"\n\n" length:2] withTimeout:-1 tag:0];
}

-(void)readBody:(NSUInteger)length {
    inHeaders = NO;
    [[self socket] readDataToLength:length withTimeout:-1 tag:0];
}

- (void)processHeaders {
}
#pragma mark -
#pragma mark AsyncSocketDelegate

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag {
    if(inHeaders) {
        self.curHeaders = [NSMutableDictionary dictionary];
        int skip = 0;
        if (*(char*)[data bytes] == '\0')
            skip = 1;
        NSString *search = [[NSString alloc] initWithBytesNoCopy:(void *)[data bytes] + skip length:[data length] - skip encoding:NSASCIIStringEncoding freeWhenDone:NO];
        NSMutableArray *contents = (NSMutableArray *)[search componentsSeparatedByString:@"\n"];
        [search release];
        self.curCommand = [contents objectAtIndex:0];
        
        NSRange rest = {1, [contents count] - 1};
        for(NSString *line in [contents subarrayWithRange:rest]) {
            NSRange colon = [line rangeOfString:@":"];
            if(colon.location != NSNotFound)
                [self.curHeaders setObject:[[line substringFromIndex:colon.location + 1] lowercaseString] forKey:[line substringToIndex:colon.location]];
        }
        
        NSString *contentLength = [self.curHeaders objectForKey:@"content-length"];
        if (contentLength) {
            [self readBody:atoi([contentLength cStringUsingEncoding:NSASCIIStringEncoding])];
        }
        else {
            // no body
            [self receiveFrame:self.curCommand headers:self.curHeaders body:nil];
            [self readHeader];
        }
    }
    else {
        [self receiveFrame:self.curCommand headers:self.curHeaders body:data];
        [self readHeader];
    }
}          

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
	if(doAutoconnect) {
		[self connect];
	}
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
	if([[self delegate] respondsToSelector:@selector(stompClientDidDisconnect:)]) {
		[[self delegate] stompClientDidDisconnect: self];
	}
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
}

#pragma mark -
#pragma mark Memory management
-(void) dealloc {
	delegate = nil;
    self.curHeaders = nil;
    self.curCommand = nil;
    
	CRV_RELEASE_SAFELY(passcode);
	CRV_RELEASE_SAFELY(login);
	CRV_RELEASE_SAFELY(host);
	CRV_RELEASE_SAFELY(socket);
    
	[super dealloc];
}

@end
