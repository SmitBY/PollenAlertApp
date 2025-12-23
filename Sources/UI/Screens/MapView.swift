import SwiftUI
import GoogleMaps
import Observation

struct MapView: View {
    @State private var viewModel = MapViewModel()
    @State private var locationManager = LocationManager()
    @State private var cameraPosition = GMSCameraPosition.camera(withLatitude: 55.751244, longitude: 37.618423, zoom: 12.0)
    @State private var isShowingDiary = false
    @State private var isShowingHistory = false
    @State private var isDetailsExpanded = false
    @State private var hasCenteredOnUser = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Полноэкранная карта
            GoogleMapsView(cameraPosition: $cameraPosition, tiles: viewModel.tiles)
                .ignoresSafeArea()
            
            // 2. Верхняя панель (Floating Pill) - Смещена вниз от челки
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Pollen Alert")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        if viewModel.isUpdating {
                            HStack(spacing: 3) {
                                ProgressView()
                                    .controlSize(.mini)
                                    .scaleEffect(0.7)
                                Text("Обновление...")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    
                    // Кнопка истории
                    Button {
                        isShowingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 60) // Отступ от верхнего края (учитывая челку)
                
                Spacer()
            }
            
            // 3. Боковые кнопки
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        // Кнопка локации
                        Button {
                            if let loc = locationManager.lastLocation {
                                cameraPosition = GMSCameraPosition.camera(
                                    withTarget: loc.coordinate,
                                    zoom: 12.0
                                )
                            } else {
                                locationManager.requestPermission()
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        // Кнопка добавить запись
                        Button {
                            isShowingDiary = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .padding(12)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, isDetailsExpanded ? 220 : 140) // Динамический отступ чтобы не перекрывать карту
                }
            }

            // 4. Нижняя карточка с деталями
            if let firstTile = viewModel.tiles.first {
                VStack(spacing: 10) {
                    // Хендл для "вытягивания"
                    Capsule()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 30, height: 3)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        let personalLevel = PersonalRiskService.shared.getPersonalRiskLevel(for: firstTile)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Уровень опасности")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("\(Int(personalLevel))%")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(riskColor(personalLevel))
                            }
                            Spacer()
                            
                            // Значок статуса
                            Image(systemName: riskIcon(personalLevel))
                                .font(.system(size: 28))
                                .foregroundStyle(riskColor(personalLevel))
                        }
                        
                        if isDetailsExpanded {
                            Divider()
                                .padding(.vertical, 4)
                            
                            HStack(spacing: 12) {
                                DetailItem(title: "Деревья", value: Int(firstTile.treeIndex * 100))
                                DetailItem(title: "Трава", value: Int(firstTile.grassIndex * 100))
                                DetailItem(title: "Сорняки", value: Int(firstTile.weedIndex * 100))
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDetailsExpanded.toggle()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .ignoresSafeArea(.all, edges: .all) // Карта на весь экран!
        .sheet(isPresented: $isShowingDiary) {
            if let loc = locationManager.lastLocation {
                let h3Index = GeoUtils.latLonToH3(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                DiaryView(currentH3Index: h3Index)
            } else {
                Text("Местоположение не определено")
                    .padding()
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            HistoryView()
        }
        .onAppear {
            locationManager.requestPermission()
            NotificationService.shared.requestAuthorization()
        }
        .onChange(of: locationManager.lastLocation) { oldLoc, newLoc in
            if let loc = newLoc {
                // Автоматическое центрирование при первом получении координат
                if !hasCenteredOnUser {
                    cameraPosition = GMSCameraPosition.camera(withTarget: loc.coordinate, zoom: 12.0)
                    hasCenteredOnUser = true
                }
                
                Task {
                    await viewModel.updateVisibleRegion(
                        lat: loc.coordinate.latitude,
                        lon: loc.coordinate.longitude
                    )
                }
            }
        }
    }
    
    private func riskColor(_ level: Double) -> Color {
        if level < 30 { return .gray }
        if level < 60 { return .yellow }
        if level < 80 { return .orange }
        return .red
    }
    
    private func riskIcon(_ level: Double) -> String {
        if level < 30 { return "checkmark.circle.fill" }
        if level < 60 { return "exclamationmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }
}

struct DetailItem: View {
    let title: String
    let value: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("\(value)")
                .font(.system(.title3, design: .rounded))
                .bold()
        }
    }
}

struct GoogleMapsView: UIViewRepresentable {
    @Binding var cameraPosition: GMSCameraPosition
    var tiles: [PollenTile]
    
    // Координатор для управления полигонами, чтобы избежать пересоздания карты
    class Coordinator {
        var polygons: [GMSPolygon] = []
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = cameraPosition
        options.frame = .zero
        
        let mapView = GMSMapView(options: options)
        if let styleURL = Bundle.main.url(forResource: "MapStyle", withExtension: "json"),
           let style = try? GMSMapStyle(contentsOfFileURL: styleURL) {
            mapView.mapStyle = style
        }
        mapView.isMyLocationEnabled = true
        
        // Настройка для уменьшения телеметрии (если возможно)
        mapView.settings.compassButton = false
        mapView.settings.myLocationButton = false
        
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // Обновляем камеру только если она действительно изменилась
        let currentTarget = uiView.camera.target
        let newTarget = cameraPosition.target
        
        if abs(currentTarget.latitude - newTarget.latitude) > 0.0001 ||
           abs(currentTarget.longitude - newTarget.longitude) > 0.0001 ||
           abs(uiView.camera.zoom - cameraPosition.zoom) > 0.1 {
            uiView.animate(to: cameraPosition)
        }
        
        // Удаляем старые полигоны
        for polygon in context.coordinator.polygons {
            polygon.map = nil
        }
        context.coordinator.polygons.removeAll()
        
        // Создаем новые полигоны
        for tile in tiles {
            let coords = GeoUtils.getBoundary(for: tile.h3Index)
            let path = GMSMutablePath()
            for coord in coords {
                path.add(coord)
            }
            
            let polygon = GMSPolygon(path: path)
            let personalLevel = PersonalRiskService.shared.getPersonalRiskLevel(for: tile)
            let color = colorForRisk(personalLevel)
            
            polygon.fillColor = color.withAlphaComponent(0.3)
            polygon.strokeColor = color
            polygon.strokeWidth = 2
            polygon.map = uiView
            
            context.coordinator.polygons.append(polygon)
        }
    }
    
    private func colorForRisk(_ level: Double) -> UIColor {
        if level < 30 { return .systemGray }
        if level < 60 { return .systemYellow }
        if level < 80 { return .systemOrange }
        return .systemRed
    }
}

#Preview {
    MapView()
}
