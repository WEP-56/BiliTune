import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useParams } from "react-router";

import { addToast } from "@heroui/react";
import { useRequest } from "ahooks";

import type { Media } from "@/service/user-video-archives-list";

import { CollectionType } from "@/common/constants/collection";
import ScrollContainer, { type ScrollRefObject } from "@/components/scroll-container";
import { getSeriesArchives } from "@/service/series-archives";
import { getSeriesInfo } from "@/service/series-info";
import { useModalStore } from "@/store/modal";
import { usePlayList } from "@/store/play-list";
import { useSettings } from "@/store/settings";
import { useUser } from "@/store/user";

import Header from "../header";
import Operations from "../operation";
import SeriesGridList from "./grid-list";
import SeriesList from "./list";

const Series = () => {
  const { id } = useParams();
  const user = useUser(state => state.user);
  const displayMode = useSettings(state => state.displayMode);
  const playList = usePlayList(state => state.playList);
  const addList = usePlayList(state => state.addList);

  const [keyword, setKeyword] = useState<string>();
  const [order, setOrder] = useState("pubtime");

  const scrollRef = useRef<ScrollRefObject>(null);

  const { data: meta, loading: infoLoading } = useRequest(
    async () => {
      if (!id) return;
      const res = await getSeriesInfo({ series_id: Number(id) });
      return res?.data?.meta;
    },
    {
      ready: Boolean(id),
      refreshDeps: [id],
    },
  );

  const isCreatedBySelf = Boolean(meta?.mid) && Boolean(user?.mid) && meta?.mid === user?.mid;

  const [medias, setMedias] = useState<Media[]>([]);
  const [pageNum, setPageNum] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [loadingMore, setLoadingMore] = useState(false);

  useEffect(() => {
    setMedias([]);
    setPageNum(1);
    setTotalCount(0);
    setKeyword("");
    setOrder("pubtime");
  }, [id]);

  const fetchArchives = useCallback(async () => {
    if (!id || !meta || loadingMore) return;
    try {
      setLoadingMore(true);
      const res = await getSeriesArchives({
        mid: Number(meta.mid),
        series_id: Number(id),
        sort: "desc",
        pn: pageNum,
        ps: 30,
      });
      const archives = res?.data?.archives ?? [];
      const mapped: Media[] = archives.map(a => ({
        id: a.aid,
        title: a.title,
        cover: a.pic,
        duration: a.duration,
        pubtime: a.pubdate,
        bvid: a.bvid,
        upper: { mid: Number(meta.mid), name: "" },
        cnt_info: { collect: 0, play: a.stat?.view ?? 0, danmaku: 0, vt: a.stat?.vt ?? 0 },
        enable_vt: Number(a.enable_vt ?? 0),
        vt_display: a.vt_display,
        is_self_view: false,
      }));
      setMedias(prev => [...prev].concat(mapped));
      const total = res?.data?.page?.total ?? 0;
      setTotalCount(prev => (prev > 0 ? prev : total));
      setPageNum(prev => prev + 1);
    } finally {
      setLoadingMore(false);
    }
  }, [id, meta, loadingMore, pageNum]);

  useEffect(() => {
    if (meta?.total) {
      fetchArchives();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [meta]);

  const filteredMedias = useMemo(() => {
    let result = medias;
    if (keyword) {
      result = result.filter(item => item.title.toLowerCase().includes(keyword.toLowerCase()));
    }
    switch (order) {
      case "play":
        result = [...result].sort((a, b) => (b.cnt_info?.play || 0) - (a.cnt_info?.play || 0));
        break;
      case "pubtime":
        result = [...result].sort((a, b) => (b.pubtime || 0) - (a.pubtime || 0));
        break;
      default:
        break;
    }
    return result;
  }, [medias, keyword, order]);

  const onPlayAll = () => {
    if (filteredMedias.length > 0) {
      playList(
        filteredMedias.map(item => ({
          type: "mv",
          bvid: item.bvid,
          title: item.title,
          cover: item.cover,
          ownerMid: item.upper?.mid,
          ownerName: item.upper?.name,
        })),
      );
    }
  };

  const addToPlayList = () => {
    if (filteredMedias.length > 0) {
      addList(
        filteredMedias.map(item => ({
          type: "mv",
          bvid: item.bvid,
          title: item.title,
          cover: item.cover,
          ownerMid: item.upper?.mid,
          ownerName: item.upper?.name,
        })),
      );
    }
  };

  const handleMenuAction = async (key: string, item: Media) => {
    switch (key) {
      case "play-next":
        usePlayList.getState().addToNext({
          type: "mv",
          title: item.title,
          cover: item.cover,
          bvid: item.bvid,
          sid: item.id,
          ownerName: item.upper?.name,
          ownerMid: item.upper?.mid,
        });
        break;
      case "add-to-playlist":
        usePlayList.getState().addList([
          {
            type: "mv",
            title: item.title,
            cover: item.cover,
            bvid: item.bvid,
            sid: item.id,
            ownerName: item.upper?.name,
            ownerMid: item.upper?.mid,
          },
        ]);
        break;
      case "favorite":
        useModalStore.getState().onOpenFavSelectModal({
          rid: item.id,
          type: 2,
          title: item.title,
        });
        break;
      case "download-audio":
        await window.electron.addMediaDownloadTask({
          outputFileType: "audio",
          title: item.title,
          cover: item.cover,
          bvid: item.bvid,
        });
        addToast({
          title: "已添加下载任务",
          color: "success",
        });
        break;
      case "download-video":
        await window.electron.addMediaDownloadTask({
          outputFileType: "video",
          title: item.title,
          cover: item.cover,
          bvid: item.bvid,
        });
        addToast({
          title: "已添加下载任务",
          color: "success",
        });
        break;
      case "bililink":
        window.electron.openExternal(`https://www.bilibili.com/video/${item.bvid}`);
        break;
      default:
        break;
    }
  };

  const getScrollElement = useCallback(() => {
    return scrollRef.current?.osInstance()?.elements().viewport as HTMLElement | null;
  }, []);

  const hasMore = useMemo(() => {
    const total = totalCount || meta?.total || 0;
    return medias.length < total;
  }, [medias.length, totalCount, meta?.total]);

  const initialLoading = infoLoading || (medias.length === 0 && loadingMore);

  return (
    <ScrollContainer enableBackToTop ref={scrollRef} resetOnChange={id} className="h-full w-full px-4 pb-6">
      <Header
        type={CollectionType.VideoSeries}
        cover={medias?.[0]?.cover}
        title={meta?.name}
        desc={meta?.description}
        upMid={meta?.mid}
        mediaCount={meta?.total}
      />

      <Operations
        loading={initialLoading}
        type={CollectionType.VideoSeries}
        order={order}
        onKeywordSearch={setKeyword}
        onOrderChange={setOrder}
        orderOptions={[
          { key: "pubtime", label: "最近投稿" },
          { key: "play", label: "最多播放" },
        ]}
        mediaCount={meta?.total}
        isCreatedBySelf={isCreatedBySelf}
        onPlayAll={onPlayAll}
        onAddToPlayList={addToPlayList}
      />

      {displayMode === "card" ? (
        <SeriesGridList
          className="min-h-0 flex-1"
          data={filteredMedias}
          loading={loadingMore}
          getScrollElement={getScrollElement}
          onMenuAction={handleMenuAction}
          hasMore={hasMore}
          onLoadMore={fetchArchives}
        />
      ) : (
        <SeriesList
          className="min-h-0 flex-1"
          data={filteredMedias}
          loading={loadingMore}
          getScrollElement={getScrollElement}
          onMenuAction={handleMenuAction}
          hasMore={hasMore}
          onLoadMore={fetchArchives}
        />
      )}
    </ScrollContainer>
  );
};

export default Series;
