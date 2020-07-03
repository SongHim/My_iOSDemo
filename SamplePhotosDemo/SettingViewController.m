//
//  SettingViewController.m
//  Uploadphoto
//
//  Created by niewei on 2019/12/2.
//  Copyright © 2019年 songhm. All rights reserved.
//

#import "SettingViewController.h"
#import "CommanHeader.h"
#import "AsyncUdpSocket.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#include "interface.h"

@interface SettingViewController ()<UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate,AsyncUdpSocketDelegate>
{
	UITableView *settingTableView;
}

/*@property (nonatomic, strong) NSString *ip;
@property (nonatomic, strong) NSString *port;
@property (nonatomic, strong) UITextField *identity;*/

@property (nonatomic, strong) UITextField *ip;
@property (nonatomic, strong) UITextField *port;

@end

@implementation SettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	[self.navigationItem setTitle:@"设置"];
	
	UITabBarItem* tabBarItem = [[UITabBarItem alloc] initWithTitle:@"设置" image:[UIImage imageNamed:@"settings.png"] tag:101];
	self.tabBarItem = tabBarItem;
	
	//UIBarButtonItem *uploadBtn = [[UIBarButtonItem alloc]initWithTitle:@"广播" style:UIBarButtonItemStylePlain target:self action:@selector(MakeUDP)];
	//self.navigationItem.rightBarButtonItem = uploadBtn;
	
	settingTableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 44 + 20, SCREEN_WIDTH, SCREEN_HEIGHT - 20 - 44 - 49) style:UITableViewStyleGrouped];
	[self.view addSubview:settingTableView];
	settingTableView.delegate = self;
	settingTableView.dataSource = self;
	settingTableView.bounces = NO;
	settingTableView.showsVerticalScrollIndicator = NO;//不显示右侧滑块
	settingTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;//分割线
	
	UITapGestureRecognizer *tap1 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
	tap1.cancelsTouchesInView = NO;
	[self.view addGestureRecognizer:tap1];
	
}

-(void)viewTapped:(UITapGestureRecognizer*)tap1
{
	[self.view endEditing:YES];
}
/*
//做udp 请求
-(void)MakeUDP
{
	//实例化
	AsyncUdpSocket *socket = [[AsyncUdpSocket alloc]initWithDelegate:self];
	//启动本地端口
	[socket localPort];
	
	NSTimeInterval timeout = 30;//发送超时时间
	
	NSString *request = @"request Identification code";//发送给服务器的内容
	
	NSData *data = [NSData dataWithData:[request dataUsingEncoding:NSASCIIStringEncoding]];
	
	int port = 9003;//端口
	//self.port = [NSString stringWithFormat:@"%d", port];
	self.port = @"9002";
	NSError *error;
	
	//发送广播设置
	[socket enableBroadcast:YES error:&error];
	//把得到的目标ip 最后的数字更换为255（意思是搜索全部的）
	NSArray *strArr = [[self getIPAddress] componentsSeparatedByString:@"."];
	
	NSMutableArray *muArr = [NSMutableArray arrayWithArray:strArr];
	
	[muArr replaceObjectAtIndex:(strArr.count - 2) withObject:@"255"];
	[muArr replaceObjectAtIndex:(strArr.count - 1) withObject:@"255"];
	NSString *finalStr = [muArr componentsJoinedByString:@"."];//目标ip
	NSLog(@"ip=%@", finalStr);
	
 
	 发送请求
	 sendData:发送的内容
	 toHost:目标的ip
	 port:端口号
	 timeOut:请求超时
 
	BOOL _isOK = [socket sendData :data toHost:[NSString stringWithFormat:@"%@",finalStr] port:port withTimeout:timeout tag:1];
	if (_isOK) {
		//udp请求成功
		NSLog(@"udp请求成功");
	}else{
		//udp请求失败
		NSLog(@"udp请求失败啦");
	}
	
	[socket receiveWithTimeout:30 tag:0];//启动接收线程 - n?秒超时
	
	NSLog(@"开始啦");
}

//接受信息
- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port{
	
	NSString* result;
	
	result = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	
	NSLog(@"%@", result);
	self.identity.text = [result copy];
	NSString *message = [[NSString alloc]initWithFormat:@"标识码：%@", result];
	[self showError:message];
	
	NSLog(@"%@", host);
	self.ip = [host copy];
	NSLog(@"ipipipip==%@", self.ip);
	NSLog(@"收到啦");
	
	[self onUdpSocketDidClose:sock];
	
	return NO;
}

//接受失败
-(void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error{
	
	NSLog(@"没有收到啊 ");
	[self showError:@"没有识别到啊，请重试！"];
	[self onUdpSocketDidClose:sock];
}

//发送失败
-(void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error{
	
	NSLog(@"%@",error);
	[self showError:@"发送失败!"];
	NSLog(@"没有发送啊");
	[self onUdpSocketDidClose:sock];
	
}

//开始发送
-(void)onUdpSocket:(AsyncUdpSocket *)sock didSendDataWithTag:(long)tag{
	
	NSLog(@"发送啦");
}

//关闭广播
-(void)onUdpSocketDidClose:(AsyncUdpSocket *)sock{
	
	NSLog(@"关闭啦");
}

#pragma mark 获取当前IP
- (NSString *)getIPAddress {
	NSString *address = @"error";
	struct ifaddrs *interfaces = NULL;
	struct ifaddrs *temp_addr = NULL;
	int success = 0;
	// retrieve the current interfaces - returns 0 on success
	success = getifaddrs(&interfaces);
	if (success == 0) {
		// Loop through linked list of interfaces
		temp_addr = interfaces;
		while(temp_addr != NULL) {
			if(temp_addr->ifa_addr->sa_family == AF_INET) {
				// Check if interface is en0 which is the wifi connection on the iPhone
				if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
					// Get NSString from C String
					address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
				}
			}
			temp_addr = temp_addr->ifa_next;
		}
	}
	// Free memory
	freeifaddrs(interfaces);
	return address;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	//分组数 也就是section数
	return 3;
}

//设置每个分组下tableview的行数
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}
//每个分组上边预留的空白高度
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section == 1)
	{
		return 80;
	}
	return 40;
}

//每一个分组下对应的tableview 高度
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0) {
		return 40;
	}
	return 50;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSString *title = nil;
	if (section == 0)
	    title = @"标识码";
	
	return title;
}

//设置每行对应的cell（展示的内容）
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = NULL;
	if (indexPath.section == 0){
		cell = [tableView dequeueReusableCellWithIdentifier:@"identity"];
		if (!cell)
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"identity"];
		}
		
		CGRect frame = cell.contentView.frame;
		self.identity = [[UITextField alloc]initWithFrame:frame];
		self.identity.delegate = self;
		self.identity.autocorrectionType = UITextAutocorrectionTypeNo;
		[cell.contentView addSubview:self.identity];
		
	}
	else{
		cell = [tableView dequeueReusableCellWithIdentifier:@"sure"];
		if (!cell)
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sure"];
		}
		cell.textLabel.text = @"确定";
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
	}
	return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0){
		
	}
	else{
		
		if ([self.identity.text isEqualToString:@""])
		{
			[self showError:@"标识码为空，请设置！"];
		}
		else
		{
			BOOL ipisempty = [self isBlankString:self.ip];
			BOOL portisempty = [self isBlankString:self.port];
			if (ipisempty || portisempty)
			{
				[self showError:@"标示码有误，请广播！！！"];
				return;
			}
			int port = [self.port intValue];
			int sock = Connected((char *)self.port.UTF8String, port);
			NSLog(@"sock===%d", sock);
			if (sock < 0)
			{
				[self showError:@"连接失败！！！"];
				return;
			}
			NSString *sockfd = [NSString stringWithFormat:@"%d", sock];
			NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
			[userDefaults setObject:sockfd forKey:SOCKFD];
			[userDefaults setObject:self.identity forKey:IDENTITY];
			[self showError:@"设置成功！"];
		}
	}
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
	[self.view endEditing:YES];
}

- (void)showError:(NSString *)errorMsg {
	// 1.弹框提醒
	// 初始化对话框
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
	// 弹出对话框
	[self presentViewController:alert animated:true completion:nil];
}

- (BOOL)isBlankString:(NSString *)str {
	NSString *string = str;
	if (string == nil || string == NULL) {
		return YES;
	}
	if ([string isKindOfClass:[NSNull class]]) {
		return YES;
	}
	if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
		return YES;
	}
	
	return NO;
}
*/

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	//分组数 也就是section数
	return 3;
}

//设置每个分组下tableview的行数
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}
//每个分组上边预留的空白高度
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section == 2)
	{
		return 60;
	}
	return 30;
}

//每一个分组下对应的tableview 高度
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0 || indexPath.section == 1) {
		return 40;
	}
	return 50;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSString *title = nil;
	if (section == 0)
		title = @"ip";
	else if (section == 1)
		title = @"port";
	
	return title;
}

//设置每行对应的cell（展示的内容）
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = NULL;
	if (indexPath.section == 0){
		cell = [tableView dequeueReusableCellWithIdentifier:@"ip"];
		if (!cell)
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ip"];
		}
		
		CGRect frame = cell.contentView.frame;
		self.ip = [[UITextField alloc]initWithFrame:frame];
		self.ip.delegate = self;
		self.ip.autocorrectionType = UITextAutocorrectionTypeNo;
		self.ip.text = (NSString*)[[NSUserDefaults standardUserDefaults] objectForKey:SERVER_NAME];
		//self.ip.keyboardType = UIKeyboardTypeNumberPad;
		[cell.contentView addSubview:self.ip];
		
	}
	else if (indexPath.section == 1){
		cell = [tableView dequeueReusableCellWithIdentifier:@"port"];
		if (!cell)
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"port"];
		}
		
		CGRect frame = cell.contentView.frame;
		self.port = [[UITextField alloc]initWithFrame:frame];
		self.port.delegate = self;
		self.port.autocorrectionType = UITextAutocorrectionTypeNo;
		self.port.text = (NSString*)[[NSUserDefaults standardUserDefaults] objectForKey:PORTID];
		//self.port.keyboardType = UIKeyboardTypeNumberPad;
		[cell.contentView addSubview:self.port];
		
	}
	else if (indexPath.section == 2){
		cell = [tableView dequeueReusableCellWithIdentifier:@"sure"];
		if (!cell)
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sure"];
		}
		cell.textLabel.text = @"确定";
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
	}
	return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0){
		
	}
	else if (indexPath.section == 1){
		
	}
	else if (indexPath.section == 2){
		
		if ([self.ip.text isEqualToString:@""]||[self.port.text isEqualToString:@""]) {
			[self showError:@"设置错误！"];
		}
		else
		{
			NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
			[userDefaults setObject:self.ip.text forKey:SERVER_NAME];
			[userDefaults setObject:self.port.text forKey:PORTID];
			[self showError:@"设置成功！"];
		}
		
	}
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
	[self.view endEditing:YES];
}

- (void)showError:(NSString *)errorMsg {
	// 1.弹框提醒
	// 初始化对话框
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
	// 弹出对话框
	[self presentViewController:alert animated:true completion:nil];
}

@end
