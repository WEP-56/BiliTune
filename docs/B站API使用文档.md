# BiliTune B站 API 使用文档

> 基于 bilibili-api 文档项目 + biu / BBPlayer 实际使用代码整理，覆盖 BiliTune 需要的所有 B 站 API

---

## 目录

1. [认证体系](#1-认证体系)
2. [WBI 签名算法](#2-wbi-签名算法)
3. [登录相关](#3-登录相关)
4. [视频信息](#4-视频信息)
5. [音频流获取](#5-音频流获取)
6. [搜索](#6-搜索)
7. [收藏夹](#7-收藏夹)
8. [用户相关](#8-用户相关)
9. [动态](#9-动态)
10. [历史与稍后再看](#10-历史与稍后再看)
11. [互动](#11-互动)
12. [评论](#12-评论)
13. [弹幕](#13-弹幕)
14. [推荐与排行](#14-推荐与排行)
15. [极验验证码](#15-极验验证码)
16. [Cookie 刷新](#16-cookie-刷新)
17. [播放上报](#17-播放上报)
18. [通用响应格式](#18-通用响应格式)

---

## 1. 认证体系

### 1.1 Cookie 凭据

所有需要登录的 API 依赖以下 Cookie 字段：

| Cookie 名 | 用途 | 必要性 |
|-----------|------|--------|
| `SESSDATA` | 身份识别，GET 请求鉴权 | 需登录的 API 必须 |
| `bili_jct` | CSRF Token，POST 操作防跨站 | 写操作必须 |
| `BUVID3` | 设备标识 | 风控相关，可自动生成 |
| `BUVID4` | 设备标识 | 风控相关，可自动生成 |
| `DedeUserID` | 用户 UID | 辅助 |

### 1.2 认证流程

```
请求发出前：
1. verify=true → 检查 SESSDATA 是否存在
2. POST/DELETE/PATCH → 自动添加 csrf = bili_jct
3. wbi=true → 对参数进行 WBI 签名（见第2节）
4. wbi2=true → 添加鼠标风控参数
5. sign=true → APP 签名（移动端特有）
```

### 1.3 请求头伪装

部分 API（特别是音频/视频流 URL）需要伪装请求头：

```
Referer: https://www.bilibili.com
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ...
```

---

## 2. WBI 签名算法

> 大部分 Web 端 API 需要 WBI 签名才能访问

### 2.1 获取签名密钥

```
GET https://api.bilibili.com/x/web-interface/nav
Cookie: SESSDATA=xxx
```

响应中提取：
```json
{
  "data": {
    "wbi_img": {
      "img_url": "https://i0.hdslb.com/bfs/wbi/xxx.png",    // → img_key
      "sub_url": "https://i0.hdslb.com/bfs/wbi/yyy.png"     // → sub_key
    }
  }
}
```

提取方式：取 URL 最后一段文件名（不含 `.png`）

### 2.2 计算 mixin_key

```typescript
// 打乱表 (固定值)
const mixinKeyEncTab = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
  27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 16,
  20, 36, 34, 17, 6, 22, 48, 44, 13, 52, 37, 4, 40, 25, 51, 11,
  55, 7, 24, 1, 21, 56, 57, 30, 54, 26, 0, 59, 60, 61, 62, 63
];

function getMixinKey(raw: string): string {
  return mixinKeyEncTab
    .map(k => raw.charCodeAt(k))
    .map(c => String.fromCharCode(c))
    .join('')
    .slice(0, 32);
}

const mixinKey = getMixinKey(img_key + sub_key);
```

### 2.3 签名请求

```typescript
function signWbi(params: Record<string, string>, mixinKey: string): Record<string, string> {
  // 1. 添加当前时间戳
  params['wts'] = Math.floor(Date.now() / 1000).toString();

  // 2. 过滤特殊字符（! ' ( ) *）
  const filtered = Object.fromEntries(
    Object.entries(params).map(([k, v]) => [k, v.replace(/[!'()*]/g, '')])
  );

  // 3. 按 key 字典排序拼接
  const query = Object.keys(filtered)
    .sort()
    .map(k => `${encodeURIComponent(k)}=${encodeURIComponent(filtered[k])}`)
    .join('&');

  // 4. MD5 计算签名
  const wRid = md5(query + mixinKey);

  return { ...filtered, w_rid: wRid };
}
```

### 2.4 密钥缓存

密钥每日更新，建议缓存到当日结束：

```typescript
// 缓存策略：每日获取一次
const CACHE_KEY = 'wbi_keys';
const CACHE_DURATION = 24 * 60 * 60 * 1000; // 24小时
```

---

## 3. 登录相关

### 3.1 二维码扫码登录

**步骤 1：获取二维码**

```
GET https://passport.bilibili.com/x/passport-login/web/qrcode/generate?source=main-fe-header
```

响应：
```json
{
  "data": {
    "url": "https://passport.bilibili.com/h5-app/passport/login/scan?navhide=1...",  // 二维码内容
    "qrcode_key": "xxx"  // 轮询密钥
  }
}
```

**步骤 2：轮询扫码状态**

```
GET https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key={key}&source=main-fe-header
```

响应码：

| code | 含义 |
|------|------|
| 86101 | 未扫码 |
| 86102 | 已扫码，未确认 |
| 0 | ✅ 已确认登录 |

登录成功时，从 **响应头 Set-Cookie** 中提取 `SESSDATA` 和 `bili_jct`。

### 3.2 短信验证码登录

**步骤 1：获取极验参数**

```
GET https://passport.bilibili.com/x/passport-login/captcha
```

**步骤 2：完成极验验证**（见第15节）

**步骤 3：发送验证码**

```
POST https://passport.bilibili.com/x/passport-login/web/sms/send
Content-Type: application/x-www-form-urlencoded

tel=手机号&cid=1&source=main_web&token={极验token}&challenge={}&validate={}&seccode={}
```

**步骤 4：验证码登录**

```
POST https://passport.bilibili.com/x/passport-login/web/login/sms
Content-Type: application/x-www-form-urlencoded

tel=手机号&cid=1&code=验证码&source=main_web&captcha_key={发送时返回的key}&keep=true
```

### 3.3 密码登录

**步骤 1：获取 RSA 公钥**

```
GET https://passport.bilibili.com/x/passport-login/web/key
```

响应：`data.hash` + `data.key`（RSA 公钥）

**步骤 2：加密密码**

```typescript
// 将 hash + 原始密码 拼接后用 RSA 公钥加密
const encrypted = RSAEncrypt(hash + password, publicKey);
```

**步骤 3：登录**

```
POST https://passport.bilibili.com/x/passport-login/web/login
Content-Type: application/x-www-form-urlencoded

username=账号&password={加密后密码}&keep=true&key={步骤1返回的key}
&token={极验token}&challenge={}&validate={}&seccode={}
```

---

## 4. 视频信息

### 4.1 视频详情

```
GET https://api.bilibili.com/x/web-interface/view
参数: bvid=BV1xx411c7mD 或 aid=170001
认证: 不需要
```

关键字段：
```json
{
  "bvid": "BV1xx411c7mD",
  "aid": 170001,
  "cid": 123456,           // 第一个分P的cid
  "title": "视频标题",
  "pic": "https://...",     // 封面
  "owner": {
    "mid": 123,             // UP主UID
    "name": "UP主名",
    "face": "https://..."   // 头像
  },
  "stat": {
    "view": 10000,          // 播放量
    "danmaku": 500,         // 弹幕数
    "like": 800             // 点赞数
  },
  "pages": [                // 分P列表
    { "cid": 123456, "part": "P1标题", "duration": 300 }
  ]
}
```

### 4.2 分P列表

```
GET https://api.bilibili.com/x/player/pagelist
参数: bvid=BV1xx411c7mD 或 aid=170001
认证: 不需要
```

### 4.3 视频统计

```
GET https://api.bilibili.com/x/web-interface/archive/stat
参数: bvid=BV1xx411c7mD 或 aid=170001
认证: 不需要
```

### 4.4 获取播放器信息 (bgm_info)

```
GET https://api.bilibili.com/x/player/wbi/v2
参数: aid=xxx&cid=xxx
认证: 需要登录 + WBI签名
```

关键字段：`data.bgminfo` — 视频关联的精确歌曲信息（歌名、艺术家），用于歌词匹配。

---

## 5. 音频流获取

### 5.1 视频 DASH 流

```
GET https://api.bilibili.com/x/player/wbi/playurl
参数:
  avid={aid}
  cid={cid}
  qn=0              // 视频质量，音频模式用0
  fnval=4048        // 请求DASH格式 (16=DASH, 4048=含HiRes+杜比)
  otype=json
认证: 不需要 (但需WBI签名)
```

关键响应结构：
```json
{
  "data": {
    "dash": {
      "audio": [
        {
          "id": 30280,           // 音质ID
          "base_url": "https://",  // 音频URL
          "backup_url": ["https://"],
          "bandwidth": 320000,
          "codecid": 0            // 0=AAC, 1=FLAC
        }
      ],
      "dolby": {
        "audio": [...]           // 杜比音轨
      },
      "flac": {
        "audio": {...}           // 无损音轨
      }
    }
  }
}
```

音质 ID 对照：

| ID | 音质 | 编码 |
|----|------|------|
| 30216 | 64kbps | AAC |
| 30232 | 128kbps | AAC |
| 30280 | 320kbps | AAC |
| 30250 | 无损 | FLAC |
| 30251 | 杜比全景声 | E-AC-3 |

⚠️ 音频 URL 含 `deadline` 参数，约 6 小时过期。需要在播放前检查有效性，过期需重新获取。

### 5.2 音频区播放

```
GET https://www.bilibili.com/audio/music-service-c/url
参数:
  songid={auid}     // 音频区ID (au开头)
  quality=2         // 1=标准 2=高品质 3=无损
认证: 需要登录
```

### 5.3 音频详情

```
GET https://www.bilibili.com/audio/music-service-c/song/info
参数: sid={auid}
认证: 需要登录
```

---

## 6. 搜索

### 6.1 综合搜索

```
GET https://api.bilibili.com/x/web-interface/wbi/search/all/v2
参数: keyword=关键词&page=1
认证: 不需要 + WBI签名
```

### 6.2 分类搜索

```
GET https://api.bilibili.com/x/web-interface/wbi/search/type
参数:
  keyword=关键词
  search_type=video       // video/bili_user/media_bangumi/live/article
  page=1
  order=totalrank         // totalrank/click/pubdate/dm
认证: 不需要 + WBI签名
```

### 6.3 搜索建议

```
GET https://s.search.bilibili.com/main/suggest
参数: term=关键词
认证: 不需要
```

### 6.4 热搜词

```
GET https://s.search.bilibili.com/main/hotword
认证: 不需要
```

### 6.5 默认搜索词

```
GET https://api.bilibili.com/x/web-interface/wbi/search/default
认证: 不需要 + WBI签名
```

---

## 7. 收藏夹

### 7.1 获取用户创建的收藏夹列表

```
GET https://api.bilibili.com/x/v3/fav/folder/created/list-all
参数: up_mid={UID}&type=2
认证: 不需要（自己的需要SESSDATA）
```

### 7.2 获取收藏夹内容

```
GET https://api.bilibili.com/x/v3/fav/resource/list
参数:
  media_id={收藏夹ID}
  pn=1                    // 页码
  ps=20                   // 每页数量
  keyword=                // 搜索关键词（可选）
  order=mtime             // mtime=最近收藏, view=最多播放, pubtime=最新投稿
认证: 不需要
```

### 7.3 获取收藏夹所有资源ID

```
GET https://api.bilibili.com/x/v3/fav/resource/ids
参数: media_id={收藏夹ID}
认证: 不需要
```

### 7.4 收藏/取消收藏

```
POST https://api.bilibili.com/x/v3/fav/resource/deal
Content-Type: application/x-www-form-urlencoded

rid={aid}&type=2&add_media_ids={目标收藏夹ID}&del_media_ids={移除收藏夹ID}
Cookie: SESSDATA=xxx
csrf={bili_jct}
```

### 7.5 新建收藏夹

```
POST https://api.bilibili.com/x/v3/fav/folder/add
Content-Type: application/x-www-form-urlencoded

title=收藏夹标题&intro=简介&privacy=0  // 0=公开, 1=私密
Cookie: SESSDATA=xxx
csrf={bili_jct}
```

### 7.6 修改收藏夹

```
POST https://api.bilibili.com/x/v3/fav/folder/edit
参数: media_id={ID}&title=新标题&intro=新简介&privacy=0
认证: 需要登录 + csrf
```

### 7.7 删除收藏夹

```
POST https://api.bilibili.com/x/v3/fav/folder/del
参数: media_ids={ID}  // 逗号分隔多个
认证: 需要登录 + csrf
```

### 7.8 删除收藏夹中的资源

```
POST https://api.bilibili.com/x/v3/fav/resource/batch-del
参数: media_id={收藏夹ID}&resources={aid:2}  // 格式: 资源ID:资源类型(2=视频)
认证: 需要登录 + csrf
```

### 7.9 获取已收藏/订阅的收藏夹

```
GET https://api.bilibili.com/x/v3/fav/folder/collected/list
参数: up_mid={UID}&pn=1&ps=20
认证: 需要登录
```

---

## 8. 用户相关

### 8.1 用户基本信息

```
GET https://api.bilibili.com/x/space/wbi/acc/info
参数: mid={UID}
认证: 不需要 + WBI签名
```

### 8.2 用户空间投稿

```
GET https://api.bilibili.com/x/space/wbi/arc/search
参数:
  mid={UID}
  pn=1&ps=30
  order=pubdate          // pubdate/click/stow
认证: 不需要 + WBI签名
```

### 8.3 关注列表

```
GET https://api.bilibili.com/x/relation/followings
参数: vmid={UID}&pn=1&ps=20&order=desc
认证: 需要登录
```

### 8.4 关注/取关

```
POST https://api.bilibili.com/x/relation/modify
参数: fid={目标UID}&act=1    // 1=关注, 2=取关
认证: 需要登录 + csrf
```

### 8.5 关注分组

```
GET https://api.bilibili.com/x/relation/tags
认证: 需要登录
```

### 8.6 检查关注状态

```
GET https://api.bilibili.com/x/space/wbi/acc/relation
参数: mid={目标UID}
认证: 需要登录 + WBI签名
```

---

## 9. 动态

### 9.1 关注UP主动态

```
GET https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all
参数: type=all             // all=全部, video=视频
      offset={下一页offset}
认证: 需要登录
```

### 9.2 用户空间动态

```
GET https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/space
参数: host_mid={UID}&offset={下一页offset}
认证: 不需要
```

### 9.3 动态类型

| DynamicType | MajorType | 说明 |
|-------------|-----------|------|
| DYNAMIC_TYPE_AV | MAJOR_TYPE_ARCHIVE | 视频投稿 |
| DYNAMIC_TYPE_PGC | MAJOR_TYPE_PGC | 番剧更新 |
| DYNAMIC_TYPE_ARTICLE | MAJOR_TYPE_ARTICLE | 专栏 |
| DYNAMIC_TYPE_MUSIC | MAJOR_TYPE_MUSIC | 音频 |
| DYNAMIC_TYPE_LIVE_RCMD | MAJOR_TYPE_LIVE_RCMD | 直播 |

---

## 10. 历史与稍后再看

### 10.1 播放历史 (游标分页)

```
GET https://api.bilibili.com/x/web-interface/history/cursor
参数: cursor={上一页max}&view_at={上一页view_at}&type=all     // all=全部, archive=视频, live=直播
认证: 需要登录
```

### 10.2 搜索历史

```
GET https://api.bilibili.com/x/web-interface/history/search
参数: keyword=关键词&pn=1&ps=20
认证: 需要登录
```

### 10.3 删除历史条目

```
POST https://api.bilibili.com/x/v2/history/delete
参数: kid={历史记录ID}   // 格式: aid 或 epid
认证: 需要登录 + csrf
```

### 10.4 清空历史

```
POST https://api.bilibili.com/x/v2/history/clear
认证: 需要登录 + csrf
```

### 10.5 稍后再看列表

```
GET https://api.bilibili.com/x/v2/history/toview
认证: 需要登录
```

### 10.6 添加稍后再看

```
POST https://api.bilibili.com/x/v2/history/toview/add
参数: aid={aid}
认证: 需要登录 + csrf
```

### 10.7 删除稍后再看

```
POST https://api.bilibili.com/x/v2/toview/del
参数: viewed=true       // true=删除已看, 或 aid=xxx 删除单条
认证: 需要登录 + csrf
```

### 10.8 清空稍后再看

```
POST https://api.bilibili.com/x/v2/toview/clear
认证: 需要登录 + csrf
```

---

## 11. 互动

### 11.1 点赞

```
POST https://api.bilibili.com/x/web-interface/like
参数: aid={aid}&like=1    // 1=点赞, 2=取消
认证: 需要登录 + csrf
```

### 11.2 投币

```
POST https://api.bilibili.com/x/web-interface/coin/add
参数: aid={aid}&multiply=1&select_like=1    // multiply=1~2, select_like=是否同时点赞
认证: 需要登录 + csrf
```

### 11.3 三连

```
POST https://api.bilibili.com/x/web-interface/like/triple
参数: aid={aid}
认证: 需要登录 + csrf
```

### 11.4 检查点赞状态

```
GET https://api.bilibili.com/x/web-interface/archive/has/like
参数: aid={aid}
认证: 需要登录
```

### 11.5 检查投币状态

```
GET https://api.bilibili.com/x/web-interface/archive/coins
参数: aid={aid}
认证: 需要登录
```

### 11.6 检查收藏状态

```
GET https://api.bilibili.com/x/v2/fav/video/favoured
参数: aid={aid}
认证: 需要登录
```

---

## 12. 评论

### 12.1 评论列表

```
GET https://api.bilibili.com/x/v2/reply
参数:
  type=1                // 1=视频, 2=话题, 11=音频
  oid={aid}             // 资源ID
  sort=2                // 0=按时间, 2=按热度
  pn=1&ps=20
认证: 不需要
```

### 12.2 评论回复

```
GET https://api.bilibili.com/x/v2/reply/reply
参数:
  type=1
  oid={aid}
  root={主评论ID}
  pn=1&ps=20
认证: 不需要
```

### 12.3 点赞评论

```
POST https://api.bilibili.com/x/v2/reply/action
参数: type=1&oid={aid}&rpid={评论ID}&action=1    // 1=点赞, 0=取消
认证: 需要登录 + csrf
```

---

## 13. 弹幕

### 13.1 获取分段弹幕 (protobuf)

```
GET https://api.bilibili.com/x/v2/dm/web/seg.so
参数:
  type=1
  oid={cid}
  pid={aid}
  segment_index={分段序号}     // 6分钟一段，第1段=1
认证: 不需要
```

响应为 protobuf 二进制数据，需解码解析。

### 13.2 弹幕 protobuf 结构

```
message DanmakuElem {
  int64 id = 1;
  int32 progress = 2;     // 出现时间(ms)
  int32 mode = 3;         // 1=滚动, 4=底部, 5=顶部
  int32 fontsize = 4;
  uint32 color = 5;       // 十进制RGB
  string content = 7;     // 弹幕内容
  ...
}
```

---

## 14. 推荐与排行

### 14.1 推荐视频

```
GET https://api.bilibili.com/x/web-interface/index/top/feed/rcmd
参数: fresh_type=3&ps=30
认证: 不需要 (登录后更精准)
```

### 14.2 热门视频

```
GET https://api.bilibili.com/x/web-interface/popular
参数: pn=1&ps=20
认证: 不需要
```

### 14.3 排行榜

```
GET https://api.bilibili.com/x/web-interface/ranking/v2
参数: rid={分区ID}         // 0=全站, 3=音乐, 28=原创音乐
      type=all            // all=全部, origin=原创
认证: 不需要
```

### 14.4 合集/系列列表

```
GET https://api.bilibili.com/x/polymer/web-space/seasons_archives_list
参数: mid={UID}&season_id={合集ID}&sort_reverse=false&page_num=1&page_size=30
认证: 不需要
```

### 14.5 视频分区

音乐相关分区 ID：

| 分区 | ID |
|------|-----|
| 音乐·原创 | 28 |
| 音乐·翻唱 | 31 |
| 音乐·VOCALOID·UTAU | 30 |
| 音乐·演奏 | 59 |
| 音乐·MV | 193 |
| 音乐·音乐现场 | 29 |
| 鬼畜 | 119 |

---

## 15. 极验验证码

### 15.1 触发条件

当 API 响应包含 `v_voucher` 字段时，需要完成极验验证。

### 15.2 处理流程

**步骤 1：注册极验**

```
POST https://api.bilibili.com/x/gaia/vgate/register
参数: v_voucher={voucher_token}
认证: 不需要
```

响应：
```json
{
  "data": {
    "geetest": {
      "gt": "...",
      "challenge": "...",
      "product": "embed"
    }
  }
}
```

**步骤 2：加载极验 JS 并弹出验证**

```html
<script src="https://static.geetest.com/v4/gt4.js"></script>
```

```javascript
initGeetest4({
  gt: data.gt,
  challenge: data.challenge,
  product: 'bind'
}, (captchaObj) => {
  captchaObj.onReady(() => captchaObj.verify());
  captchaObj.onSuccess(() => {
    const result = captchaObj.getValidate();
    // result: { lot_number, captcha_output, pass_token, gen_time }
  });
});
```

**步骤 3：验证**

```
POST https://api.bilibili.com/x/gaia/vgate/validate
参数:
  v_voucher={voucher}
  challenge={challenge}
  validate={captcha_output}
  seccode={pass_token}
认证: 不需要
```

**步骤 4：重发原请求**

将 `gaia_vtoken`（步骤3返回）附加到原请求参数中重新发送。

---

## 16. Cookie 刷新

### 16.1 刷新流程

```
步骤1: 检查是否需要刷新
GET https://passport.bilibili.com/x/passport-login/web/cookie/info?csrf={bili_jct}

步骤2: RSA加密 correspondPath
  - 生成 timestamp
  - 明文: "refresh_{timestamp}"
  - 用 RSA-OAEP (SHA-256) 公钥加密
  - 结果 → correspondPath

步骤3: 获取 refresh_csrf
GET https://www.bilibili.com/correspond/1/{correspondPath}
  - 从返回的HTML中提取 <div id="1-name">{refresh_csrf}</div>

步骤4: 刷新Cookie
POST https://passport.bilibili.com/x/passport-login/web/cookie/refresh
参数: csrf={refresh_csrf}&refresh_token={当前refresh_token}&source=main_web
  - 从响应Set-Cookie获取新SESSDATA/bili_jct
  - 从响应体获取新refresh_token

步骤5: 确认刷新
POST https://passport.bilibili.com/x/passport-login/web/confirm/refresh
参数: refresh_token={旧refresh_token}
```

---

## 17. 播放上报

### 17.1 开始播放

```
POST https://api.bilibili.com/x/click-now/web/heartbeat
参数:
  aid={aid}&cid={cid}
  played_time=0
  realtime=0
  start_progress=0
认证: 需要登录 + csrf
```

### 17.2 播放心跳

```
POST https://api.bilibili.com/x/web-interface/heartbeat
参数:
  aid={aid}&cid={cid}
  played_time={已播放秒数}
  realtime={当前播放位置}
  start_progress=0
  type=3
认证: 需要登录 + csrf
```

建议间隔：每 15 秒发送一次。

### 17.3 播放结束

同播放心跳，`played_time` 设为视频总时长。

---

## 18. 通用响应格式

### 18.1 标准响应

```json
{
  "code": 0,
  "message": "0",
  "data": { ... }
}
```

| code | 含义 |
|------|------|
| 0 | 成功 |
| -400 | 请求错误 |
| -403 | 访问权限不足 |
| -404 | 啥都木有 |
| 62002 | 资源不存在 |
| -352 | 风控校验失败 |
| -101 | 账号未登录 |

### 18.2 错误处理建议

```typescript
function handleApiError(code: number) {
  switch (code) {
    case -101:
      // 跳转登录页
      break;
    case -352:
      // 触发 WBI 签名刷新
      break;
    case -403:
      // 提示无权限
      break;
    default:
      // 通用错误提示
  }
}
```

---

## 附录 A：BV/AV 号互转

```typescript
const XOR_CODE = 23442827791579n;
const MASK_CODE = 2251799813685247n;
const MAX_AID = 1n << 51n;
const ALPHABET = 'FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBzZrkDuXohS';
const ENCODE_MAP = [8, 7, 0, 5, 1, 3, 2, 4, 6];
const DECODE_MAP = [2, 4, 6, 5, 7, 3, 1, 0, 8];

function av2bv(aid: number): string {
  const bv = new Array(9).fill('');
  let tmp = (MAX_AID | BigInt(aid)) ^ XOR_CODE;
  for (let i = 0; i < 9; i++) {
    bv[ENCODE_MAP[i]] = ALPHABET[Number(tmp % 58n)];
    tmp /= 58n;
  }
  return 'BV1' + bv.join('');
}

function bv2av(bvid: string): number {
  const bvidArr = bvid.slice(3).split('');
  const arr = DECODE_MAP.map(i => bvidArr[i]);
  let tmp = 0n;
  for (const c of arr) {
    tmp = tmp * 58n + BigInt(ALPHABET.indexOf(c));
  }
  return Number((tmp & MASK_CODE) ^ XOR_CODE);
}
```

---

## 附录 B：CDN 图片参数优化

B站图片 URL 支持添加参数进行优化：

```
原始: https://i0.hdslb.com/bfs/archive/xxx.jpg
优化: https://i0.hdslb.com/bfs/archive/xxx.jpg@480w_270h_1c.webp
```

| 参数 | 说明 |
|------|------|
| `@{w}w_{h}h_1c.webp` | 指定宽高，输出webp |
| `@{w}w_{h}h_1c.jpg` | 指定宽高，输出jpg |
| `@{s}q.webp` | 指定质量 (1-100) |

---

## 附录 C：b23.tv 短链解析

```typescript
async function resolveB23ShortUrl(code: string): Promise<string> {
  const url = `https://b23.tv/${code}`;
  const resp = await fetch(url, { redirect: 'manual' });
  const location = resp.headers.get('location');
  // 从 location 中解析 bvid/aid
  return location;
}
```

---

## 附录 D：第三方歌词 API

### D.1 网易云音乐

```
搜索: POST https://music.163.com/api/search/get/web
  参数: s=歌名&type=1&limit=10

歌词: POST https://music.163.com/api/song/lyric
  参数: id=歌曲ID&lv=1&tv=1
```

### D.2 QQ音乐

```
搜索: GET https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?key=歌名

歌词: GET https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=歌曲mid&format=json
  注意: 返回 Base64 编码歌词
```

### D.3 酷狗音乐

```
搜索: GET https://mobileservice.kugou.com/api/v3/search/song?keyword=歌名&page=1&pagesize=10

歌词: GET https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=歌名&duration=秒数
  → 获取 hash → GET https://lyrics.kugou.com/download?ver=1&client=pc&id=歌词ID&hash=hash
  → 返回 Base64 编码歌词
```

### D.4 LRCLIB

```
搜索: GET https://lrclib.net/api/search?q=歌名
歌词: GET https://lrclib.net/api/get?artist_name=艺术家&track_name=歌名
```
