import 'package:flutter/material.dart';
import 'dart:async';

/// Performance optimization utilities
class PerformanceOptimization {
  /// Debounce function calls
  static Function debounce(
    Function callback, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    Timer? timer;

    return ([args]) {
      timer?.cancel();
      timer = Timer(delay, () => callback(args));
    };
  }

  /// Throttle function calls
  static Function throttle(
    Function callback, {
    Duration interval = const Duration(milliseconds: 500),
  }) {
    DateTime? lastCallTime;

    return ([args]) {
      final now = DateTime.now();

      if (lastCallTime == null ||
          now.difference(lastCallTime!).inMilliseconds >=
              interval.inMilliseconds) {
        lastCallTime = now;
        callback(args);
      }
    };
  }

  /// Batch operations for better performance
  static Future<void> batchOperations(
    List<Function> operations, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    for (final operation in operations) {
      operation();
      await Future.delayed(delay);
    }
  }
}

/// Lazy loading widget
class LazyLoadingWidget extends StatefulWidget {
  final Widget Function(BuildContext) builder;
  final Duration delay;
  final Widget? placeholder;

  const LazyLoadingWidget({
    super.key,
    required this.builder,
    this.delay = const Duration(milliseconds: 300),
    this.placeholder,
  });

  @override
  State<LazyLoadingWidget> createState() => _LazyLoadingWidgetState();
}

class _LazyLoadingWidgetState extends State<LazyLoadingWidget> {
  late Future<void> _loadingFuture;

  @override
  void initState() {
    super.initState();
    _loadingFuture = Future.delayed(widget.delay);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return widget.builder(context);
        }

        return widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(),
            );
      },
    );
  }
}

/// Cached image widget with lazy loading
class OptimizedCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Duration fadeDuration;

  const OptimizedCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.fadeDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_not_supported),
          ),
        );
      },
    );
  }
}

/// Memory-efficient list view
class OptimizedListView extends StatelessWidget {
  final List items;
  final Widget Function(BuildContext, int) itemBuilder;
  final int cacheExtent;
  final Axis scrollDirection;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.cacheExtent = 250,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: itemBuilder,
      cacheExtent: cacheExtent.toDouble(),
      scrollDirection: scrollDirection,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: padding,
    );
  }
}

/// Memory-efficient grid view
class OptimizedGridView extends StatelessWidget {
  final List items;
  final Widget Function(BuildContext, int) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final int cacheExtent;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.crossAxisCount,
    this.childAspectRatio = 1.0,
    this.mainAxisSpacing = 10,
    this.crossAxisSpacing = 10,
    this.cacheExtent = 250,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemBuilder: itemBuilder,
      cacheExtent: cacheExtent.toDouble(),
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: padding,
    );
  }
}

/// Repaint boundary for performance optimization
class OptimizedRepaintBoundary extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const OptimizedRepaintBoundary({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return RepaintBoundary(child: child);
  }
}

/// Single child scroll view with performance optimization
class OptimizedSingleChildScrollView extends StatelessWidget {
  final Widget child;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final Axis scrollDirection;

  const OptimizedSingleChildScrollView({
    super.key,
    required this.child,
    this.physics,
    this.padding,
    this.scrollDirection = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      physics: physics ?? const BouncingScrollPhysics(),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

/// Visibility wrapper for performance
class OptimizedVisibility extends StatelessWidget {
  final Widget child;
  final bool visible;
  final Widget? replacement;

  const OptimizedVisibility({
    super.key,
    required this.child,
    required this.visible,
    this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      replacement: replacement ?? const SizedBox.shrink(),
      child: child,
    );
  }
}

/// Frame rate monitor widget (for debugging)
class FrameRateMonitor extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const FrameRateMonitor({
    super.key,
    required this.child,
    this.enabled = false,
  });

  @override
  State<FrameRateMonitor> createState() => _FrameRateMonitorState();
}

class _FrameRateMonitorState extends State<FrameRateMonitor> {
  late Stopwatch _stopwatch;
  int _frameCount = 0;
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _stopwatch = Stopwatch()..start();
      _scheduleTick();
    }
  }

  void _scheduleTick() {
    if (!widget.enabled) return;

    Future.delayed(const Duration(milliseconds: 16), () {
      _frameCount++;

      if (_stopwatch.elapsedMilliseconds >= 1000) {
        setState(() {
          _fps = _frameCount * (1000 / _stopwatch.elapsedMilliseconds);
        });
        _frameCount = 0;
        _stopwatch.reset();
      }

      _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'FPS: ${_fps.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    if (widget.enabled) {
      _stopwatch.stop();
    }
    super.dispose();
  }
}

