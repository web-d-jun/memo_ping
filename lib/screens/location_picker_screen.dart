import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// 지도에서 위치를 선택하는 화면.
/// 탭한 좌표를 [LatLng]으로 반환한다.
/// 사용: Navigator.push → 결과로 LatLng? 반환
class LocationPickerScreen extends StatefulWidget {
  /// 수정 시 기존 좌표로 초기 핀 설정
  final LatLng? initialPosition;
  final double initialRadius;

  const LocationPickerScreen({
    super.key,
    this.initialPosition,
    this.initialRadius = 200,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // 서울 시청 기본값 — GPS 실패 시 폴백
  static const LatLng _defaultCenter = LatLng(37.5665, 126.9780);

  final MapController _mapController = MapController();

  LatLng? _pickedPosition;   // 사용자가 탭한 좌표
  LatLng _mapCenter = _defaultCenter;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _pickedPosition = widget.initialPosition;
      _mapCenter = widget.initialPosition!;
    } else {
      // 초기 로드 시 현재 위치로 지도 이동
      _moveToCurrentLocation(initial: true);
    }
  }

  /// 현재 GPS 위치를 가져와 지도 중심 이동.
  /// [initial] true면 핀을 찍지 않고 이동만 함.
  Future<void> _moveToCurrentLocation({bool initial = false}) async {
    setState(() => _loadingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _mapCenter = latlng;
        if (!initial) _pickedPosition = latlng; // 버튼 탭 시엔 핀도 이동
      });
      _mapController.move(latlng, 16.0);
    } catch (_) {
      // 위치 실패 시 기본 중심 유지
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _onMapTap(TapPosition _, LatLng latlng) {
    setState(() => _pickedPosition = latlng);
  }

  void _confirm() {
    if (_pickedPosition == null) return;
    Navigator.pop(context, _pickedPosition);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.initialRadius;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          color: const Color(0xFF1A1A2E),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '위치 선택',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── 지도 ──────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15.0,
              onTap: _onMapTap,
            ),
            children: [
              // OpenStreetMap 타일
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.memo_ping',
              ),
              // 반경 원
              if (_pickedPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _pickedPosition!,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                      borderColor: const Color(0xFF26C6DA),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              // 핀 마커
              if (_pickedPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedPosition!,
                      width: 48,
                      height: 56,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        color: Color(0xFF5C6BC0),
                        size: 48,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── 안내 문구 (핀 미선택 시) ─────────────
          if (_pickedPosition == null)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded,
                        color: Color(0xFF26C6DA), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '지도를 탭하여 위치를 선택하세요',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 현재 위치 버튼 ─────────────────────────
          Positioned(
            right: 16,
            bottom: _pickedPosition != null ? 120 : 32,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5C6BC0),
              elevation: 4,
              onPressed: _loadingLocation
                  ? null
                  : () => _moveToCurrentLocation(initial: false),
              child: _loadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF5C6BC0),
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          // ── 하단 확인 버튼 ─────────────────────────
          if (_pickedPosition != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 좌표 표시
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      '${_pickedPosition!.latitude.toStringAsFixed(5)}, '
                      '${_pickedPosition!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C6BC0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '이 위치로 설정',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
