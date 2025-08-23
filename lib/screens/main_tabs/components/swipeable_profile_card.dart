import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SwipeableProfileCard extends StatefulWidget {
  final String? image;
  final String name;
  final int? age;
  final String? professionType;
  final String? professionSubtype;
  final bool sendingInvite;
  final VoidCallback? onInvite;
  final VoidCallback? onSwipe;
  final bool showFetchingBadge;

  const SwipeableProfileCard({
    super.key,
    required this.image,
    required this.name,
    required this.age,
    required this.professionType,
    required this.professionSubtype,
    required this.sendingInvite,
    this.onInvite,
    this.onSwipe,
    this.showFetchingBadge = false,
  });

  @override
  State<SwipeableProfileCard> createState() => _SwipeableProfileCardState();
}

class _SwipeableProfileCardState extends State<SwipeableProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _rotationAnimation;
  bool _isSwiping = false;
  double _dragDx = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _swipeAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _rotationAnimation =
        Tween<double>(begin: 0.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSwipe?.call();
        _controller.reset();
        setState(() {
          _isSwiping = false;
          _dragDx = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _professionIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'student':
        return Icons.school;
      case 'engineer':
        return Icons.engineering;
      case 'designer':
        return Icons.brush;
      case 'doctor':
        return Icons.local_hospital;
      case 'artist':
        return Icons.palette;
      case 'other':
        return Icons.work_outline;
      default:
        return Icons.work_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final imageHeight = screen.height * 0.75;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          if (_isSwiping) return;
          setState(() => _dragDx = 0.0);
        },
        onHorizontalDragUpdate: (details) {
          if (_isSwiping) return;
          setState(() => _dragDx += details.delta.dx);
        },
        onHorizontalDragEnd: (details) {
          if (_isSwiping) return;
          final velocity = details.primaryVelocity ?? 0.0;
          if (velocity.abs() > 200 || _dragDx.abs() > 80) {
            setState(() => _isSwiping = true);
            final isLeft = (_dragDx < 0) || (velocity < 0);
            final endRotation = isLeft ? -0.21 : 0.21;

            _swipeAnimation = Tween<Offset>(
              begin: Offset(_dragDx / screen.width, 0),
              end: Offset(isLeft ? -2.0 : 2.0, 0.4),
            ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

            _rotationAnimation = Tween<double>(
              begin: (_dragDx / screen.width) * 0.21,
              end: endRotation,
            ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

            _controller.forward();
          } else {
            _swipeAnimation = Tween<Offset>(
              begin: Offset(_dragDx / screen.width, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
            _rotationAnimation = Tween<double>(
              begin: (_dragDx / screen.width) * 0.21,
              end: 0.0,
            ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
            _controller.forward().then((_) {
              setState(() {
                _dragDx = 0.0;
                _isSwiping = false;
              });
            });
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            Offset offset;
            double rotation;
            if (_isSwiping) {
              offset = _swipeAnimation.value;
              rotation = _rotationAnimation.value;
            } else {
              offset = Offset(_dragDx / screen.width, 0);
              rotation = (_dragDx / screen.width) * 0.21;
            }
            return Transform.translate(
              offset: Offset(offset.dx * screen.width, offset.dy * screen.height * 0.15),
              child: Transform.rotate(angle: rotation, child: child),
            );
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: Stack(
                    children: [
                      if (widget.image != null && widget.image!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.image!,
                          width: double.infinity,
                          height: imageHeight,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF8B4DFF),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.userCircle,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.userCircle,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Color.fromARGB(100, 0, 0, 0),
                                Color.fromARGB(200, 0, 0, 0),
                              ],
                              stops: [0.0, 0.5, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.showFetchingBadge)
                Positioned(
                  right: 20,
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8B4DFF),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.name}, ${widget.age ?? "--"}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                color: Color(0xFF2D1B3A),
                              ),
                            ),
                            if (widget.professionType != null &&
                                widget.professionType!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B4DFF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _professionIcon(widget.professionType),
                                      color: const Color(0xFF8B4DFF),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${widget.professionType![0].toUpperCase()}${widget.professionType!.substring(1)}${widget.professionSubtype != null && widget.professionSubtype!.isNotEmpty ? ' • ${widget.professionSubtype}' : ''}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: Color(0xFF6D4B86),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: widget.sendingInvite ? null : widget.onInvite,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF8B4DFF), Color(0xFFA855FF)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: widget.sendingInvite
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    PhosphorIconsBold.heart,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}