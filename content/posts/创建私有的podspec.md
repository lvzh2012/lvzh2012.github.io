+++

date = '2025-12-11T00:58:55+08:00'
draft = false
title = 'CocoaPods'
tags = ['CocoaPods']

categories = ['CocoaPods']

cover = "https://images.unsplash.com/photo-1763972456511-fc3cf9bdca83?q=80&w=1740&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

+++

# 创建私有的podspec

### 1.创建一个lib的连接库

```
$ pod lib create [NAME]   
举例：pod lib creaet MYKit
```

上面的是创建一个lib模板库，这个是从github上下载下来的模板。当然也可以自己制作模板（这个有心人可以试一试）。

- 在创建的过程中会让你选择对应的一些基本的配置比如开发语言，测试的矿建了，是否包含实例工程等。
- 其中MYKit里面包含两个文件一个是Assets(存放资源的)，一个是Classes(库文件)
- 需要把对应的资源文件和库文件添加到对应的文件里面去。
- 验证库文件的正确性，在Example中执行pod install并测试库的完成性和稳定性。

### 2. 添加一个远程的仓库

这个是你的库的仓库，是用来上传代码的仓库

```
git remote add [NAME]  [URL]     添加NAME是你的仓库的名字 URL是地址
git push -u origin master  上传
```

这个时候要注意的一点是，利用私有库添加的必须添加过Tag标签

```
git tags 查看当前标签 
git tag '0.1.0' 添加标签
git push [NAME]  --tags  上传标签
```

### 3.制作podspec文件，修改对应的文件的格式

- $pod lib lint 验证是否正确
- $pod lib lint —allow-warnings 这个只是验证本地的pod库符合规范。不一定能够安装通过的。

```
-> MYKit (0.1.0) 
MYKit passed validation.
```

- pod spec lint 这个是验证对应的podspec书写是否符合规范，这个只是验证写的是否正确。

如果出现验证通过说明没有问题

### 4.添加pod repo的文件

```
$ pod repo add [NAME] [URL]   //添加repo
$ pod repo push [repo-Name] [repo-Name.podspec]   //上传podspec
```

然后在本地的文件夹下面查看对应的索引库是否存在

~/.cocoapods/repos/ 下是否存在对应的那个索引库

对应的私有索引库和代码库都是Git管理的。按照git的操作步骤去添加对应的文件和删除。

**注意**

在私有库导入对应的framework的时候需要在对应的target目录下检测对应的目标文件配置以及是否有依赖的库。