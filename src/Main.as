[Setting name="Remove All Favorites"]
bool S_removeAllFavorites = false;

void Update(float dt) {
    if (S_removeAllFavorites) {
        S_removeAllFavorites = false;
        startnew(RemoveAllFavoriteMaps);
    }
}

void Main() {
    if (Meta::GetPluginFromID("MLHook") !is null) {
        MLHook::RegisterMLHook(HookExample(), "CustomRemoveFavoritesButton");
        InjectCustomButton();
    } else {
        NotifyWarn("MLHook not found", "MLHook is not installed. The custom button will not be injected, but you can still use the script, through the Openplanet settings.");
    }

    NadeoServices::AddAudience("NadeoLiveServices");

    if (IO::FileExists(IO::FromStorageFolder("FavoriteMapsToRemove.txt"))) {
        array<string> remainingUids = LoadUidsFromFile();
        if (remainingUids.Length > 0) {
            NotifyInfo("Resume Removal", "You have unfinished favorite map removals. Resuming...", 10000);
            startnew(RemoveMapsFromFile);
        }
    }
}

void InjectCustomButton() {
    string mlCode = _IO::File::ReadSourceFileToEnd("src/manialink.xml");
    MLHook::InjectManialinkToPlayground("", mlCode, false);
}

class HookExample : MLHook::HookMLEventsByType {
    void OnEvent(const string &in type, const string[] &in data) {
        if (type == "RemoveAllFavorites") {
            startnew(RemoveAllFavoriteMaps);
        }
    }
}

void RemoveAllFavoriteMaps() {
    if (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
        NotifyError("Error", "Not authenticated with NadeoLiveServices.");
        return;
    }

    array<string> favoriteMapUids = GetFavoriteMapUids();
    if (favoriteMapUids.Length == 0) {
        NotifyInfo("No Favorites", "You don't have any favorite maps.");
        return;
    }

    SaveUidsToFile(favoriteMapUids);
    RemoveMapsFromFile();
}

void RemoveMapsFromFile() {
    array<string> uids = LoadUidsFromFile();
    for (uint i = 0; i < uids.Length; i++) {
        RemoveFavoriteMap(uids[i]);
        uids.RemoveAt(i);
        SaveUidsToFile(uids);
        i--;
        sleep(2000);
    }

    NotifyInfo("Favorites Removed", "All favorite maps have been removed.");
    IO::Delete(IO::FromStorageFolder("FavoriteMapsToRemove.txt"));
}

array<string> GetFavoriteMapUids() {
    array<string> mapUids;
    int offset = 0;
    int length = 300;

    while (true) {
        auto req = NadeoServices::Get("NadeoLiveServices", 
            "https://live-services.trackmania.nadeo.live/api/token/map/favorite?offset=" + offset + "&length=" + length);
        req.Start();
        while (!req.Finished()) yield();

        if (req.ResponseCode() != 200) {
            NotifyError("Error", "Failed to retrieve favorite maps.");
            return mapUids;
        }

        auto response = Json::Parse(req.String());
        auto mapList = response["mapList"];

        for (uint i = 0; i < mapList.Length; i++) {
            mapUids.InsertLast(mapList[i]["uid"]);
        }

        if (mapList.Length < length) break;

        offset += length;
        sleep(2000);
    }

    return mapUids;
}

void RemoveFavoriteMap(const string &in mapUid) {
    auto req = NadeoServices::Post("NadeoLiveServices", 
        "https://live-services.trackmania.nadeo.live/api/token/map/favorite/" + mapUid + "/remove");
    req.Start();
    while (!req.Finished()) yield();

    if (req.ResponseCode() != 200) {
       NotifyError("Error", "Failed to remove map " + mapUid);
    }
}

void SaveUidsToFile(array<string> uids) {
    IO::File file(IO::FromStorageFolder("FavoriteMapsToRemove.txt"), IO::FileMode::Write);
    for (uint i = 0; i < uids.Length; i++) {
        file.Write(uids[i] + "\n");
    }
    file.Close();
}

array<string> LoadUidsFromFile() {
    array<string> uids;
    if (IO::FileExists(IO::FromStorageFolder("FavoriteMapsToRemove.txt"))) {
        IO::File file(IO::FromStorageFolder("FavoriteMapsToRemove.txt"), IO::FileMode::Read);
        while (!file.EOF()) {
            string line = file.ReadLine();
            if (line != "") {
                uids.InsertLast(line);
            }
        }
        file.Close();
    }
    return uids;
}

void OnDestroyed() {
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}
