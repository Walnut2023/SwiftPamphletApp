//
//  EditInfoView.swift
//  SwiftPamphletApp
//
//  Created by Ming Dai on 2024/3/11.
//

import InfoOrganizer
import Ink
import PhotosUI
import SMFile
import SMNetwork
import SMUI
import SwiftData
import SwiftSoup
import SwiftUI

struct EditInfoView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var info: IOInfo
    @Query(IOCategory.all) var categories: [IOCategory]
    @State private var showSheet = false

    // Inspector
    @State var isShowInspector = false
    enum InspectorType {
        case category, customSearch
    }
    @State var inspectorType: InspectorType = .category
    @AppStorage(SPC.isShowInspector) var asIsShowInspector: Bool = false
    @AppStorage(SPC.inspectorType) var asInspectorType: Int = 0
    // Tab
    @State var selectedTab = 1
    @State var isStopLoadingWeb = false
    // webarchive
    @State var savingDataTrigger = false
    // 图集
    @State var selectedPhotos = [PhotosPickerItem]()
    @State var addWebImageUrl = ""
    // 关联输入和编辑的开关
    @State var isShowRelateTextField = false

    // MARK: Text And Preview
    @State private var isShowPreview = false  // 添加预览开关状态

    var body: some View {
        VStack {
            Form {
                Section {
                    titleInputView
                    urlInputView
                }  // end Section

                Section {
                    categoryInputView
                    if isShowRelateTextField == true {
                        TextField("关联:", text: $info.relateName)
                            .rounded()
                            .foregroundStyle(Color.indigo)
                    }
                }
                // MARK: Tab 切换
                Section(footer: Text("文本支持 markdown 格式")) {
                    // TODO: markdown 获取图片链接，并能显示
                    TabView(selection: $selectedTab) {
                        textAndPreviewView()
                        webViewView()
                        imagePickAndShowView()
                    }
                    .onChange(of: info.url) { oldValue, newValue in
                        tabSwitch()
                        isStopLoadingWeb = false
                    }
                    .onChange(
                        of: info,
                        { oldValue, newValue in
                            tabSwitch()
                        }
                    )
                    .onAppear {
                        tabSwitch()
                    }
                }
            }  // end form
            .padding(10)
            .inspector(isPresented: $isShowInspector) {
                switch inspectorType {
                case .category:
                    EditCategoryView()
                case .customSearch:
                    EditCustomSearchView()
                }

            }
            .toolbar {
                Button("关闭", systemImage: "sidebar.right") {
                    isShowInspector.toggle()
                }
            }
            .onAppear(perform: {
                // 标签
                searchTerms(arr: parseSearchTerms())
                // AppStorage
                if asInspectorType == 0 {
                    inspectorType = .category
                } else if asInspectorType == 1 {
                    inspectorType = .customSearch
                }
                isShowInspector = asIsShowInspector
                // 关联编辑
                if info.relateName.isEmpty == false {
                    isShowRelateTextField = true
                }
            })
            .onChange(of: term) { oldValue, newValue in
                searchTerms(arr: parseSearchTerms())
            }
            .onChange(of: isShowInspector) { oldValue, newValue in
                asIsShowInspector = newValue
            }
            .onChange(of: inspectorType) { oldValue, newValue in
                if newValue == InspectorType.category {
                    asInspectorType = 0
                } else if newValue == InspectorType.customSearch {
                    asInspectorType = 1
                }
            }
            .onChange(of: info.relateName) { oldValue, newValue in
                if info.relateName.isEmpty == true {
                    isShowRelateTextField = false
                } else {
                    isShowRelateTextField = true
                }
            }
            Spacer()
        }  // end VStack
    }

    // MARK: Image
    @State private var largeImageUrlStr = ""
    #if os(macOS)
        @State private var largeNSImage: NSImage? = nil
    #elseif os(iOS)
        @State private var largeUIImage: UIImage? = nil
    #endif

    @MainActor
    @ViewBuilder
    func imagePickAndShowView() -> some View {
        VStack {
            HStack {
                PhotosPicker(selection: $selectedPhotos, matching: .not(.videos)) {
                    Label("选择照片图片", systemImage: "photo.on.rectangle.angled")
                }
                .onChange(of: selectedPhotos) { oldValue, newValue in
                    convertDataToImage()
                }
                TextField("添加图片 url:", text: $addWebImageUrl).rounded()
                    .onSubmit {
                        if let webImageUrl = URL(string: addWebImageUrl) {
                            info.imgs?.append(IOImg(url: webImageUrl.absoluteString))
                            addWebImageUrl = ""
                        }
                    }
            }
            ZStack {
                ScrollView {
                    if let infoImgs = info.imgs {
                        if infoImgs.count > 0 {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)]) {
                                ForEach(Array(infoImgs.enumerated()), id: \.0) { i, img in
                                    VStack {
                                        if let data = img.imgData {
                                            #if os(macOS)
                                                if let nsImg = NSImage(data: data) {
                                                    Image(nsImage: nsImg)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .cornerRadius(5)
                                                        .onTapGesture(perform: {
                                                            largeNSImage = nsImg
                                                        })
                                                        .contextMenu {
                                                            Button {
                                                                IOInfo.updateCoverImage(
                                                                    info: info, img: img)
                                                            } label: {
                                                                Label(
                                                                    "设为封面图", image: "doc.text.image"
                                                                )
                                                            }
                                                            Button {
                                                                info.imgs?.remove(at: i)
                                                                IOImg.delete(img)
                                                            } label: {
                                                                Label("删除", image: "circle")
                                                            }

                                                        }
                                                }
                                            #elseif os(iOS)
                                                if let uiImg = UIImage(data: data) {
                                                    Image(uiImage: uiImg)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .cornerRadius(5)
                                                        .onTapGesture(perform: {
                                                            largeUIImage = uiImg
                                                        })
                                                        .contextMenu {
                                                            Button {
                                                                IOInfo.updateCoverImage(
                                                                    info: info, img: img)
                                                            } label: {
                                                                Label(
                                                                    "设为封面图", image: "doc.text.image"
                                                                )
                                                            }
                                                            Button {
                                                                info.imgs?.remove(at: i)
                                                                IOImg.delete(img)
                                                            } label: {
                                                                Label("删除", image: "circle")
                                                            }

                                                        }
                                                }
                                            #endif
                                        } else if img.url.isEmpty == false {
                                            NukeImage(url: img.url)
                                                .contextMenu {
                                                    Button {
                                                        IOInfo.updateCoverImage(
                                                            info: info, img: IOImg(url: img.url))
                                                    } label: {
                                                        Label("设为封面图", image: "doc.text.image")
                                                    }
                                                    Button {
                                                        #if os(macOS)
                                                            let p = NSPasteboard.general
                                                            p.copyText(img.url)
                                                        #elseif os(iOS)
                                                            let p = UIPasteboard.general
                                                            p.string = img.url
                                                        #endif
                                                    } label: {
                                                        Label("复制图片链接", image: "circle")
                                                    }
                                                    Button {
                                                        info.imgs?.remove(at: i)
                                                        IOImg.delete(img)
                                                    } label: {
                                                        Label("删除", image: "circle")
                                                    }
                                                }
                                                .onTapGesture {
                                                    largeImageUrlStr = img.url
                                                }
                                        }
                                    }  // end VStack
                                }  // end ForEach
                            }  // end LazyVGrid
                        }
                    }  // end if let
                    if info.imageUrls.isEmpty == false {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)]) {
                            ForEach(info.imageUrls, id: \.self) { img in
                                NukeImage(height: 150, url: img)
                                    .contextMenu {
                                        Button {
                                            IOInfo.updateCoverImage(
                                                info: info, img: IOImg(url: img))
                                        } label: {
                                            Label("设为封面图", image: "doc.text.image")
                                        }
                                        Button {
                                            #if os(macOS)
                                                let p = NSPasteboard.general
                                                p.copyText(img)
                                            #elseif os(iOS)
                                                let p = UIPasteboard.general
                                                p.string = img
                                            #endif
                                        } label: {
                                            Label("复制图片链接", image: "circle")
                                        }
                                    }
                                    .onTapGesture {
                                        withAnimation {
                                            largeImageUrlStr = img
                                        }
                                    }
                            }
                        }
                    }
                }  // end scrollView
                if largeImageUrlStr.isEmpty == false {
                    NukeImage(url: largeImageUrlStr)
                        .onTapGesture {
                            withAnimation {
                                largeImageUrlStr = ""
                            }
                        }
                }
                #if os(macOS)
                    if largeNSImage != nil {
                        Image(nsImage: largeNSImage!)
                            .resizable()
                            .scaledToFit()
                            .onTapGesture {
                                withAnimation {
                                    largeNSImage = nil
                                }
                            }
                    }
                #elseif os(iOS)
                    if largeUIImage != nil {
                        Image(uiImage: largeUIImage!)
                            .resizable()
                            .scaledToFit()
                            .onTapGesture {
                                withAnimation {
                                    largeUIImage = nil
                                }
                            }
                    }
                #endif
            }
        }
        .onChange(
            of: info,
            { oldValue, newValue in
                largeImageUrlStr = ""
                #if os(macOS)
                    largeNSImage = nil
                #elseif os(iOS)
                    largeUIImage = nil
                #endif
            }
        )
        .padding(10)
        .tabItem { Label("图集", systemImage: "circle") }
        .tag(5)
    }

    // MARK: WebView
    @ViewBuilder
    private func webViewView() -> some View {
        if let url = URL(string: info.url) {
            VStack {
                WebUIViewWithSave(
                    urlStr: url.absoluteString,
                    savingDataTrigger: $savingDataTrigger,
                    savingData: $info.webArchive,
                    isStop: $isStopLoadingWeb
                )
                TextEditor(text: $info.des)
                    .frame(height: 53)
                    .padding(5)

            }
            .tabItem { Label("网页", systemImage: "circle") }
            .tag(4)
        }
    }

    // MARK: Text And Preview
    @ViewBuilder
    private func textAndPreviewView() -> some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    isShowPreview.toggle()
                } label: {
                    Label("预览", systemImage: isShowPreview ? "eye.fill" : "eye")
                }
                .help("预览 Markdown")
            }
            .padding(.horizontal)

            if isShowPreview {
                // 水平分布的编辑器和预览
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // 编辑器
                        TextEditor(text: $info.des)
                            .border(.secondary)
                            .padding(10)
                            .frame(width: geometry.size.width / 2)

                        // 分隔线
                        Divider()

                        // 预览 - 使用原来的 WebUIView
                        WebUIView(
                            html: wrapperHtmlContent(
                                content: MarkdownParser().html(from: info.des)),
                            baseURLStr: ""
                        )
                        .frame(width: geometry.size.width / 2 - 20)
                    }
                }
                .frame(minHeight: 300)
            } else {
                // 只显示编辑器
                TextEditor(text: $info.des)
                    .border(.secondary)
                    .padding(10)
                    .frame(minHeight: 300)
            }
        }
        .tabItem { Label("文本", systemImage: "circle") }
        .tag(1)
    }

    // MARK: Category
    private var categoryInputView: some View {
        HStack {
            Picker("分类:", selection: $info.category) {
                Text("未分类")
                    .tag(Optional<IOCategory>.none)
                if categories.isEmpty == false {
                    Divider()
                    ForEach(categories) { cate in
                        HStack {
                            if cate.pin == 1 {
                                Image(systemName: "pin.fill")
                            }
                            Text(cate.name)
                        }
                        .tag(Optional(cate))
                    }
                }
            }
            .onHover(perform: { hovering in
                info.category?.updateDate = Date.now
            })
            Button("管理分类", action: manageCate)
            if term.isEmpty == false {
                Button("自定标签") {
                    showSheet = true
                }
                .help("command + s")
                .sheet(
                    isPresented: $showSheet,
                    content: {
                        ScrollView(.vertical) {
                            ForEach(parseSearchTerms(), id: \.self) { term in
                                HStack {
                                    ForEach(term, id: \.self) { oneTerm in
                                        if oneTerm.description.hasPrefix("《") {
                                            Text(oneTerm)
                                                .bold()
                                        } else {
                                            Button(oneTerm) {
                                                showSheet = false
                                                info.des = "[\(oneTerm)]" + "\n" + info.des
                                            }
                                            .fixedSize()
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.leading, 1)
                            }
                            .padding(2)
                        }
                        .padding(20)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭", systemImage: "xmark") {
                                    showSheet = false
                                }
                            }
                        }
                    }
                )
                .keyboardShortcut(KeyEquivalent("s"), modifiers: .command)
            }

            Button("管理自定标签", action: manageCustomSearch)
        }
    }

    func fetchWebContent(urlString: String) async {
        let re = await fetchTitleFromUrl(urlString: info.url)
        await MainActor.run {
            if re.title.isEmpty == false {
                info.name = re.title
                if re.imageUrl.isEmpty == false {
                    IOInfo.updateCoverImage(info: info, img: IOImg(url: re.imageUrl))
                }
                info.imageUrls = re.imageUrls
            }
        }
    }

    // MARK: URL
    private var urlInputView: some View {
        HStack {
            TextField("地址:", text: $info.url, prompt: Text("输入或粘贴 url，例如 https://starming.com"))
                .rounded()
                .onSubmit {
                    info.name = "获取标题中......"

                    Task {
                        // MARK: 获取 Web 内容
                        await fetchWebContent(urlString: info.url)
                    }
                }
            if info.url.isEmpty == false {
                Button {
                    info.name = "获取标题中......"
                    Task {
                        // MARK: 获取 Web 内容
                        await fetchWebContent(urlString: info.url)
                    }
                } label: {
                    Image(systemName: "link")
                    Text("解析")
                }
                Button {
                    SMNetwork.gotoWebBrowser(urlStr: info.url)
                } label: {
                    Image(systemName: "safari")
                }
                .help("浏览器打开")
                // 本地存
                Button {
                    if info.webArchive == nil {
                        savingDataTrigger = true
                    } else {
                        info.webArchive = nil
                    }
                } label: {
                    if info.webArchive == nil {
                        Image(systemName: "square.and.arrow.down")
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                }
                .help("离线内容")
            }  // end if
        }
    }

    // MARK: 标题
    private var titleInputView: some View {
        HStack {
            TextField("标题:", text: $info.name).rounded()
            Toggle(isOn: $info.star) {
                Image(systemName: info.star ? "star.fill" : "star")
            }
            .toggleStyle(.button)
            .help("收藏")
            Toggle(isOn: $info.isArchived) {
                Image(systemName: info.isArchived ? "archivebox.fill" : "archivebox")
            }
            .toggleStyle(.button)
            .help("归档")

            Button(
                action: {
                    info.updateDate = Date.now
                },
                label: {
                    Image(systemName: "arrow.up.square")
                }
            )
            .help("提到前面")
            Button {
                isShowRelateTextField.toggle()
            } label: {
                Image(systemName: isShowRelateTextField == true ? "network.slash" : "network")
            }
            .help("关联编辑")
            .keyboardShortcut(KeyEquivalent("r"), modifiers: .command)
        }
    }

    // MARK: 自定标签
    @AppStorage(SPC.customSearchTerm) var term = ""
    @State private var searchTerms: [[String]] = [[String]]()
    func parseSearchTerms() -> [[String]] {
        let terms = term.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n")
        var sterms = [[String]]()
        for t in terms {
            if t.isEmpty == false {
                let tWithoutWhitespaces = t.trimmingCharacters(in: .whitespaces)
                if tWithoutWhitespaces.hasPrefix("//") { continue }
                let ts = t.trimmingCharacters(in: .whitespaces).split(separator: ",")
                var lineTs = [String]()
                if ts.count > 1 {
                    for oneT in ts {
                        lineTs.append(String(oneT.trimmingCharacters(in: .whitespaces)))
                    }
                } else {
                    lineTs.append(String(tWithoutWhitespaces))
                }
                sterms.append(lineTs)
            }  // end if
        }  // end for
        return sterms
    }

    @MainActor func searchTerms(arr: [[String]]) {
        searchTerms = arr
    }

    // MARK: 数据管理
    func tabSwitch() {
        if info.url.isEmpty {
            selectedTab = 1
            if info.imgs?.count ?? 0 > 0 || info.imageUrls.count > 0 {
                selectedTab = 5
            }
        } else {
            selectedTab = 4
        }
    }
    func manageCate() {
        switch inspectorType {
        case .category:
            isShowInspector.toggle()
        case .customSearch:
            inspectorType = .category
            isShowInspector = true
        }
    }
    func manageCustomSearch() {
        switch inspectorType {
        case .category:
            inspectorType = .customSearch
            isShowInspector = true
        case .customSearch:
            isShowInspector.toggle()
        }
    }

    // MARK: 图集处理
    @MainActor
    func convertDataToImage() {
        if !selectedPhotos.isEmpty {
            for item in selectedPhotos {
                Task {
                    if let imageData = try? await item.loadTransferable(type: Data.self) {
                        info.imgs?.append(IOImg(url: "", imgData: imageData))
                    }
                }
            }
        }
        selectedPhotos.removeAll()
    }

    // MARK: 获取网页内容
    func fetchTitleFromUrl(urlString: String, isFetchContent: Bool = false) async -> (
        title: String, imageUrl: String, imageUrls: [String]
    ) {
        var title = "没找到标题"
        guard let url = URL(string: urlString) else {
            return (title, "", [String]())
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            return (title, "", [String]())
        }
        guard let homepageHTML = String(data: data, encoding: .utf8),
            let soup = try? SwiftSoup.parse(homepageHTML)
        else {
            return (title, "", [String]())
        }

        // 获取标题
        let soupTitle = try? soup.title()
        let h1Title = try? soup.select("h1").first()?.text()

        var imageUrl = ""
        var imageUrls = [String]()

        // 获取图集
        do {
            let imgs = try soup.select("img").array()
            if imgs.count > 0 {

                for elm in imgs {
                    if let elmUrl = try? elm.attr("src") {
                        if elmUrl.isEmpty == false {
                            imageUrls.append(
                                SMNetwork.urlWithSchemeAndHost(url: url, urlStr: elmUrl))
                        }
                    }
                }
                var imgUrl: String?
                if imageUrls.count > 0 {
                    if imageUrls.count > 3 {
                        imgUrl = imageUrls.randomElement()
                    } else {
                        imgUrl = imageUrls.first
                    }
                    if let okImgUrl = imgUrl {
                        imageUrl = SMNetwork.urlWithSchemeAndHost(url: url, urlStr: okImgUrl)
                    }
                }

            }
        } catch {}

        if let okH1Title = h1Title {
            title = okH1Title
        }
        if soupTitle?.isEmpty == false {
            title = soupTitle ?? "没找到标题"
        }

        return (title, imageUrl, imageUrls)
    }

    // 添加 Markdown 图片处理
    private func extractMarkdownImages() {
        let parser = MarkdownParser()
        let html = parser.html(from: info.des)
        // 解析 HTML 中的图片链接
        if let doc = try? SwiftSoup.parse(html) {
            let images = try? doc.select("img").array()
            images?.forEach { img in
                if let src = try? img.attr("src") {
                    info.imageUrls.append(src)
                }
            }
        }
    }
}
