//
//  SearchView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// Comprehensive search view with filters and results
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showingFilters = false

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient with dark mode support
                LinearGradient(
                    colors: [
                        Color.backgroundGradientStart,
                        Color.backgroundGradientMiddle,
                        Color.backgroundGradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Active filters
                    if viewModel.hasActiveFilters {
                        activeFiltersView
                    }

                    // Results
                    ScrollView {
                        VStack(spacing: 20) {
                            if viewModel.isSearching {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding()
                            } else if !viewModel.searchResults.isEmpty {
                                // Search results
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(viewModel.searchResults) { photo in
                                        PhotoThumbnailView(photo: photo)
                                            .aspectRatio(1, contentMode: .fill)
                                    }
                                }
                            } else if !viewModel.searchQuery.isEmpty || viewModel.hasActiveFilters {
                                // No results
                                GlassCard(padding: 40) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 60))
                                            .foregroundColor(.secondary)

                                        Text("No Results")
                                            .font(.title2)
                                            .fontWeight(.bold)

                                        Text("Try adjusting your search or filters")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding()
                            } else {
                                // Initial state with suggestions
                                initialStateView
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadSuggestions()
            }
        }
    }

    private var searchBar: some View {
        GlassCard(padding: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                TextField("Search photos", text: $viewModel.searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: viewModel.searchQuery) { oldValue, newValue in
                        Task {
                            await viewModel.performSearch()
                        }
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .padding()
    }

    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.favoriteOnly {
                    GlassTagChip(tag: "Favorites") {
                        viewModel.favoriteOnly = false
                        Task { await viewModel.performSearch() }
                    }
                }

                ForEach(viewModel.selectedTags, id: \.self) { tag in
                    GlassTagChip(tag: tag) {
                        viewModel.selectedTags.removeAll { $0 == tag }
                        Task { await viewModel.performSearch() }
                    }
                }

                ForEach(viewModel.selectedAlbums, id: \.self) { album in
                    GlassTagChip(tag: album) {
                        viewModel.selectedAlbums.removeAll { $0 == album }
                        Task { await viewModel.performSearch() }
                    }
                }

                if viewModel.dateRange != nil {
                    GlassTagChip(tag: "Date Range") {
                        viewModel.dateRange = nil
                        Task { await viewModel.performSearch() }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Material.ultraThinMaterial)
    }

    private var initialStateView: some View {
        VStack(spacing: 24) {
            // Quick filters
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Filters")
                        .font(.headline)

                    VStack(spacing: 8) {
                        quickFilterButton(
                            title: "Favorites",
                            icon: "heart.fill",
                            action: {
                                viewModel.favoriteOnly = true
                                Task { await viewModel.performSearch() }
                            }
                        )

                        quickFilterButton(
                            title: "Recent",
                            icon: "clock.fill",
                            action: {
                                viewModel.setRecentDateRange()
                                Task { await viewModel.performSearch() }
                            }
                        )

                        quickFilterButton(
                            title: "This Month",
                            icon: "calendar",
                            action: {
                                viewModel.setThisMonthDateRange()
                                Task { await viewModel.performSearch() }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)

            // Tag suggestions
            if !viewModel.suggestedTags.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Popular Tags")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.suggestedTags.prefix(10), id: \.self) { tag in
                                    Button(action: {
                                        viewModel.selectedTags.append(tag)
                                        Task { await viewModel.performSearch() }
                                    }) {
                                        Text(tag)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Material.thin)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func quickFilterButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

/// Search filters sheet
struct SearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient with dark mode support
                LinearGradient(
                    colors: [
                        Color.backgroundGradientStart,
                        Color.backgroundGradientMiddle,
                        Color.backgroundGradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Favorite toggle
                        GlassCard {
                            Toggle(isOn: $viewModel.favoriteOnly) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                    Text("Favorites Only")
                                        .fontWeight(.medium)
                                }
                            }
                            .tint(.red)
                        }

                        // Tag filter
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Filter by Tags")
                                    .font(.headline)

                                if !viewModel.availableTags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                                Button(action: {
                                                    toggleTag(tag)
                                                }) {
                                                    Text(tag)
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(
                                                            viewModel.selectedTags.contains(tag)
                                                            ? AnyShapeStyle(Color.accentColor)
                                                            : AnyShapeStyle(Material.thin)
                                                        )
                                                        .foregroundColor(
                                                            viewModel.selectedTags.contains(tag)
                                                            ? .white
                                                            : .primary
                                                        )
                                                        .cornerRadius(16)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    Text("No tags available")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Sort order
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sort By")
                                    .font(.headline)

                                Picker("Sort Order", selection: $viewModel.sortOrder) {
                                    ForEach(PhotoSortOrder.allCases, id: \.self) { order in
                                        Text(order.displayName).tag(order)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }

                        // Clear all filters
                        if viewModel.hasActiveFilters {
                            Button(action: {
                                viewModel.clearAllFilters()
                            }) {
                                Text("Clear All Filters")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Material.thin)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Task {
                            await viewModel.performSearch()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleTag(_ tag: String) {
        if viewModel.selectedTags.contains(tag) {
            viewModel.selectedTags.removeAll { $0 == tag }
        } else {
            viewModel.selectedTags.append(tag)
        }
    }
}

// MARK: - ViewModel

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [EncryptedPhoto] = []
    @Published var isSearching = false

    // Filters
    @Published var selectedTags: [String] = []
    @Published var selectedAlbums: [String] = []
    @Published var favoriteOnly = false
    @Published var dateRange: (Date, Date)? = nil
    @Published var sortOrder: PhotoSortOrder = .dateAddedNewest

    // Suggestions
    @Published var suggestedTags: [String] = []
    @Published var availableTags: [String] = []

    var hasActiveFilters: Bool {
        !selectedTags.isEmpty || !selectedAlbums.isEmpty || favoriteOnly || dateRange != nil
    }

    func performSearch() async {
        isSearching = true
        defer { isSearching = false }

        do {
            var options = SearchManager.SearchOptions()
            options.query = searchQuery
            options.tags = selectedTags
            options.albums = selectedAlbums
            options.favoriteOnly = favoriteOnly
            options.sortOrder = sortOrder

            if let (start, end) = dateRange {
                options.dateRange = SearchManager.DateRange(start: start, end: end)
            }

            let result = try await SearchManager.shared.search(options: options)
            searchResults = result.photos
        } catch {
            searchResults = []
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }

    func clearAllFilters() {
        selectedTags = []
        selectedAlbums = []
        favoriteOnly = false
        dateRange = nil
    }

    func loadSuggestions() async {
        do {
            suggestedTags = try await SearchManager.shared.getSuggestedSearches()
            availableTags = try await TagManager.shared.getAllTags()
        } catch {
            suggestedTags = []
            availableTags = []
        }
    }

    func setRecentDateRange() {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        dateRange = (start, end)
    }

    func setThisMonthDateRange() {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        dateRange = (start, end)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
