//
//  ViewController.m
//  BabyBluetoothAppDemo
//
//  Created by 刘彦玮 on 15/8/1.
//  Copyright (c) 2015年 刘彦玮. All rights reserved.
//

/***==============================HEADER==============================***/
#import <CoreLocation/CoreLocation.h>

/***==============================END HEADER==============================***/

#import "ViewController.h"
#import "SVProgressHUD.h"
#import "AFNetworking.h"


//screen width and height
#define width [UIScreen mainScreen].bounds.size.width
#define height [UIScreen mainScreen].bounds.size.height

@interface ViewController ()<CLLocationManagerDelegate>{
    // UITableView *tableView;
    NSMutableArray *peripherals;
    NSMutableArray *peripheralsAD;
    NSMutableArray *DASOUGOU_DEVICES;
    BabyBluetooth *baby;
    
    /***==============================Variables==============================***/
    CLLocationManager *_locationManager;
    AFHTTPRequestOperationManager *_AFNetworkManager;
    /***==============================END Variables==============================***/
}

@property (nonatomic) NSMutableDictionary *sendParams;
@property (nonatomic) NSMutableArray *coordinates;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _AFNetworkManager = [AFHTTPRequestOperationManager manager];
    _sendParams = [[NSMutableDictionary alloc] init];
    _coordinates = [NSMutableArray array];
    
    NSLog(@"viewDidLoad");
    [SVProgressHUD showInfoWithStatus:@"准备打开设备"];
    
    //初始化其他数据 init other
    peripherals = [[NSMutableArray alloc]init];
    peripheralsAD = [[NSMutableArray alloc]init];
   
    //初始化BabyBluetooth 蓝牙库
    baby = [BabyBluetooth shareBabyBluetooth];
    //设置蓝牙委托
    [self babyDelegate];
    
    // 开启地理位置信息监听
    [self initializeLocationService];
}
-(void)viewDidAppear:(BOOL)animated{
    NSLog(@"viewDidAppear");
    //停止之前的连接
    [baby cancelAllPeripheralsConnection];
    //设置委托后直接可以使用，无需等待CBCentralManagerStatePoweredOn状态。
    baby.scanForPeripherals().begin();
    //baby.scanForPeripherals().begin().stop(10);
}

-(void)viewWillDisappear:(BOOL)animated{
    NSLog(@"viewWillDisappear");
}

#pragma mark -蓝牙配置和操作

//蓝牙网关初始化和委托方法设置
-(void)babyDelegate{
    
    __weak typeof(self) weakSelf = self;
    [baby setBlockOnCentralManagerDidUpdateState:^(CBCentralManager *central) {
        if (central.state == CBCentralManagerStatePoweredOn) {
            [SVProgressHUD showInfoWithStatus:@"设备打开成功，开始扫描设备"];
        }
    }];
    
    //设置扫描到设备的委托
    [baby setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
        
        [weakSelf sortAvaliableDevices];
        if ([weakSelf judgeIsAvaliable:peripheral.name]) {
            NSLog(@"find %@ %@ %@",peripheral.name,[[advertisementData objectForKey:@"kCBAdvDataServiceUUIDs"] objectAtIndex:0],RSSI);

//            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
//            [weakSelf.sendParams setObject:[userDefaults objectForKey:@"token"] forKey:@"token"];
            [weakSelf.sendParams setObject:[[advertisementData objectForKey:@"kCBAdvDataServiceUUIDs"] objectAtIndex:0] forKey:@"identifier"];
            [weakSelf.sendParams setObject:peripheral.name forKey:@"name"];
            [weakSelf.sendParams setObject:RSSI forKey:@"rssi"];
            [weakSelf.sendParams setObject:[NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
            
            NSDictionary *coorRes = [weakSelf calcFinalCoordinate:[weakSelf.coordinates copy]];
            [weakSelf.sendParams setObject:[coorRes objectForKey:@"lat"] forKey:@"lat"];
            [weakSelf.sendParams setObject:[coorRes objectForKey:@"lng"] forKey:@"lng"];
            
            [weakSelf uploadDataToServer:[weakSelf.sendParams copy]];
        }
        
        [weakSelf insertTableView:peripheral advertisementData:advertisementData];
    }];
    
    //设置发现设备的Services的委托
    [baby setBlockOnDiscoverServices:^(CBPeripheral *peripheral, NSError *error) {
        for (CBService *service in peripheral.services) {
            NSLog(@"搜索到服务:%@",service.UUID.UUIDString);
        }
        //找到cell并修改detaisText
        for (int i=0;i<peripherals.count;i++) {
            UITableViewCell *cell = [weakSelf.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            if (cell.textLabel.text == peripheral.name) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu个service",(unsigned long)peripheral.services.count];
            }
        }
    }];
    //设置发现设service的Characteristics的委托
    [baby setBlockOnDiscoverCharacteristics:^(CBPeripheral *peripheral, CBService *service, NSError *error) {
        NSLog(@"===service name:%@",service.UUID);
        for (CBCharacteristic *c in service.characteristics) {
            NSLog(@"charateristic name is :%@",c.UUID);
        }
    }];
    //设置读取characteristics的委托
    [baby setBlockOnReadValueForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
        NSLog(@"characteristic name:%@ value is:%@",characteristics.UUID,characteristics.value);
    }];
    //设置发现characteristics的descriptors的委托
    [baby setBlockOnDiscoverDescriptorsForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error) {
        NSLog(@"===characteristic name:%@",characteristic.service.UUID);
        for (CBDescriptor *d in characteristic.descriptors) {
            NSLog(@"CBDescriptor name is :%@",d.UUID);
        }
    }];
    //设置读取Descriptor的委托
    [baby setBlockOnReadValueForDescriptors:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
        NSLog(@"Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
    }];
    
    //设置查找设备的过滤器
    [baby setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName) {
        //设置查找规则是名称大于1 ， the search rule is peripheral.name length > 2
        if (peripheralName.length >2) {
            return YES;
        }
        return NO;
    }];
    
    
    [baby setBlockOnCancelAllPeripheralsConnectionBlock:^(CBCentralManager *centralManager) {
        NSLog(@"setBlockOnCancelAllPeripheralsConnectionBlock");
    }];
       
    [baby setBlockOnCancelScanBlock:^(CBCentralManager *centralManager) {
        NSLog(@"setBlockOnCancelScanBlock");
    }];
    
    /*设置babyOptions
        
        参数分别使用在下面这几个地方，若不使用参数则传nil
        - [centralManager scanForPeripheralsWithServices:scanForPeripheralsWithServices options:scanForPeripheralsWithOptions];
        - [centralManager connectPeripheral:peripheral options:connectPeripheralWithOptions];
        - [peripheral discoverServices:discoverWithServices];
        - [peripheral discoverCharacteristics:discoverWithCharacteristics forService:service];
        
        该方法支持channel版本:
            [baby setBabyOptionsAtChannel:<#(NSString *)#> scanForPeripheralsWithOptions:<#(NSDictionary *)#> connectPeripheralWithOptions:<#(NSDictionary *)#> scanForPeripheralsWithServices:<#(NSArray *)#> discoverWithServices:<#(NSArray *)#> discoverWithCharacteristics:<#(NSArray *)#>]
     */
    
    //示例:
    //扫描选项->CBCentralManagerScanOptionAllowDuplicatesKey:忽略同一个Peripheral端的多个发现事件被聚合成一个发现事件
    NSDictionary *scanForPeripheralsWithOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@YES};
    //连接设备->
//    [baby setBabyOptionsWithScanForPeripheralsWithOptions:scanForPeripheralsWithOptions connectPeripheralWithOptions:nil scanForPeripheralsWithServices:nil discoverWithServices:nil discoverWithCharacteristics:nil];
    NSTimer *timer;
    
    timer = [NSTimer scheduledTimerWithTimeInterval: 3
             
                                             target: self
             
                                           selector: @selector(scan)
             
                                           userInfo: nil
             
                                            repeats: YES];

    

}
-(void)scan
{
    [baby cancelScan];
    baby.scanForPeripherals().begin();
//    NSLog(@"devices:%@",DASOUGOU_DEVICES);
//    for(int i=0;i<[DASOUGOU_DEVICES count];i++){
//        CBPeripheral *p = [DASOUGOU_DEVICES objectAtIndex:i];
//        [p readRSSI];
////        NSLog(@"p.RSSI:%@",p.RSSI);
////        [self.sendParams setObject:p.identifier.UUIDString forKey:@"identifier"];
////        [self.sendParams setObject:p.name forKey:@"name"];
////        [self.sendParams setObject:p.RSSI forKey:@"rssi"];
////        [self.sendParams setObject:[NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
////        [self uploadDataToServer:[self.sendParams copy]];
//    }
}
- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error 
{
    NSLog(@"peripheralDidUpdateRSSI:%@",RSSI);
}
#pragma mark -UIViewController 方法
//插入table数据
-(void)insertTableView:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData{
    if(![peripherals containsObject:peripheral]){
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:peripherals.count inSection:0];
        [indexPaths addObject:indexPath];
        [peripherals addObject:peripheral];
        [peripheralsAD addObject:advertisementData];
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark -table委托 table delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return peripherals.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell"];
    CBPeripheral *peripheral = [peripherals objectAtIndex:indexPath.row];
    NSDictionary *ad = [peripheralsAD objectAtIndex:indexPath.row];
    
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    //peripheral的显示名称,优先用kCBAdvDataLocalName的定义，若没有再使用peripheral name
    NSString *localName;
    if ([ad objectForKey:@"kCBAdvDataLocalName"]) {
        localName = [NSString stringWithFormat:@"%@",[ad objectForKey:@"kCBAdvDataLocalName"]];
    }else{
        localName = peripheral.name;
    }
    
    cell.textLabel.text = localName;
    //信号和服务
    cell.detailTextLabel.text = @"读取中...";
    //找到cell并修改detaisText
    NSArray *serviceUUIDs = [ad objectForKey:@"kCBAdvDataServiceUUIDs"];
    if (serviceUUIDs) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu个service",(unsigned long)serviceUUIDs.count];
    }else{
        cell.detailTextLabel.text = [NSString stringWithFormat:@"0个service"];
    }
    
    //次线程读取RSSI和服务数量
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    // 停止扫描
    [baby cancelScan];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    CBPeripheral *peripheral =  [peripherals objectAtIndex:indexPath.row];

    [self dismissViewControllerAnimated:NO completion:^{
        [self.delegate pick:peripheral.identifier.UUIDString name:peripheral.name];
    }];
    
//    PeripheralViewContriller *vc = [[PeripheralViewContriller alloc]init];
//    vc.currPeripheral = [peripherals objectAtIndex:indexPath.row];
//    vc->baby = self->baby;
//    [self.navigationController pushViewController:vc animated:YES];
    
}

#pragma mark - 获取当前用户坐标
/***==============================FOOTER==============================***/
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    [_coordinates addObject:@{
                              @"lng":[NSNumber numberWithLong:locations[0].coordinate.longitude * 1000000],
                              @"lat":[NSNumber numberWithLong:locations[0].coordinate.latitude * 1000000]
                              }];
    
    if ([_coordinates count] > 30) {
        [_coordinates removeObjectAtIndex:0];
    }
}

- (void)initializeLocationService {
    
    // 初始化定位管理器
    _locationManager = [[CLLocationManager alloc] init];
    // 设置代理
    _locationManager.delegate = self;
    // 设置定位精确度到米
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    // 设置过滤器为无
    _locationManager.distanceFilter = kCLDistanceFilterNone;
    
    // 版本判断 系统版本大于8时, 才需要请求授权
    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
        // 用户使用期间授权
        [_locationManager requestWhenInUseAuthorization];
        
        // MARK:  iOS9新增
        // 临时开打后台定位功能  还要配置pllist
        // _locationManager.allowsBackgroundLocationUpdates = YES;
        
        // 总是授权 -- 显示其他程序时--程序在后台时可以定位
        // [_locationManager requestAlwaysAuthorization];
        
    }
    // 开始定位
    [_locationManager startUpdatingLocation];
}

// 上传数据到服务器
-(void) uploadDataToServer:(NSDictionary *) params{
    // 判断数据是否需要上传到服务器
    // [self sortAvaliableDevices];
    NSLog(@"当前样本数目：%lu,%@",(unsigned long)[_coordinates count],params);
    if([_coordinates count] > 20){
        [_AFNetworkManager PUT:@"http://ssh.jj.letme.repair:2398/bluetooth" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSLog(@"================== JSON: %@", @"success");
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"================== Error: %@", @"error");
        }];
    }
}

// 过滤出可用设备列表
-(void) sortAvaliableDevices {
    DASOUGOU_DEVICES = [NSMutableArray array];
    for(CBPeripheral *peripheral in peripherals){
        NSArray *splitRes = [peripheral.name componentsSeparatedByString:@"-"];
        if ([@"DASOUGOU" isEqualToString:splitRes[0]]) {
            [DASOUGOU_DEVICES addObject:peripheral];
        }
    }
    
}

- (BOOL) judgeIsAvaliable:(NSString *)name{
    NSArray *splitRes = [name componentsSeparatedByString:@"-"];
    return [@"DASOUGOU" isEqualToString:splitRes[0]];
}

-(IBAction)close:(id)sender
{
    
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}
-(void)pick
{
    
}


-(NSDictionary *) calcFinalCoordinate:(NSMutableArray *)intersections{
    NSMutableDictionary *map = [[NSMutableDictionary alloc] init];
    NSArray *new_intersections = [[NSArray alloc] initWithArray:intersections copyItems:YES];
    
    for (NSDictionary *val in new_intersections) {
        NSString *str = [NSString stringWithFormat:@"%@,%@",[val objectForKey:@"lng"],[val objectForKey:@"lat"]];

        if([map valueForKey:str]==nil){
            [map setValue:@1 forKey:str];
        }else{
            [map setValue:[NSNumber numberWithInt:[(NSNumber *)[map objectForKey:str] intValue]+1] forKey:str];
        }
    }
    NSString *str = @"";
    for(NSString *key in map ){
        if([str isEqualToString:@""]){
            str = key;
            continue;
        }
        if([(NSNumber *)map[key] intValue]>[(NSNumber *)map[str] intValue]){
            str = key;
        }
    }
    NSArray *firstSplit = [str componentsSeparatedByString:@","];
    return @{
             @"lng":[NSNumber numberWithFloat:([[firstSplit objectAtIndex:0] intValue]-0.5f)/1000000],
             @"lat":[NSNumber numberWithFloat:([[firstSplit objectAtIndex:1] intValue]-0.5f)/1000000]
             };
}

/***==============================END FOOTER==============================***/


@end
