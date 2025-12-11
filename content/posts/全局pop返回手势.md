+++
date = '2025-12-11T09:34:01+08:00'
draft = false
title = '全局pop返回手势'

tags = ['iOS']

categories = ['iOS']

cover = "https://images.unsplash.com/photo-1764877805075-c0cdcb2da65c?q=80&w=1740&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

+++

### 实现全局的pop手势

需要先获取系统手势交互对应interactivePopGestureRecognizer

```c
var outCount : UInt32 = 0

let ivars = class_copyIvarList(UIGestureRecognizer.self, &outCount)!

for i in 0..<outCount {

let ivar : Ivar = ivars[Int(i)]

let name = ivar_getName(ivar)

print(String(cString: name!))

}
```

##### ObjC

```objective-c
UIGestureRecognizer *sysGes = nil;

UIView *sysView = nil;

if (self.interactivePopGestureRecognizer) {

sysGes = self.interactivePopGestureRecognizer;

} else return;

if (sysGes.view) {

sysView = sysGes.view;

} else return;

NSDictionary *targetDic = [[sysGes valueForKey:@"_targets"] firstObject];

id target = nil;

SEL sel = nil;

if (targetDic) {

target = [targetDic valueForKey:@"target"];

sel = NSSelectorFromString(@"handleNavigationTransition:");

}else return;

//

UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:sel];

[sysView addGestureRecognizer:pan];
```

##### Swift

```swift
guard let sysGes = interactivePopGestureRecognizer else {return}

guard let popView = sysGes.view else {return}

let targets = sysGes.value(forKey: "_targets") as? [NSObject]

guard let targetDic = targets?.first else {return}

//取出target

guard let target = targetDic.value(forKey: "target") else {return}

let action = Selector(("handleNavigationTransition:"))

//创建自己的pop

let panGes = UIPanGestureRecognizer()

panGes.addTarget(target, action: action)

popView.addGestureRecognizer(panGes)
```

