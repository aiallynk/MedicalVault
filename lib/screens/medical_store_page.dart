import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../api_service.dart';

class MedicalStorePage extends StatefulWidget {
  const MedicalStorePage({super.key});

  @override
  State<MedicalStorePage> createState() => _MedicalStorePageState();
}

class _MedicalStorePageState extends State<MedicalStorePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cartItems = <Map<String, dynamic>>[];
  Map<String, dynamic> _cartTotals = const {'itemCount': 0, 'subtotal': 0};

  bool _loadingProducts = true;
  bool _loadingMore = false;
  bool _loadingCart = true;
  bool _mutatingCart = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

  String _category = '';
  String _sort = 'newest';
  double _minRating = 0;

  static const List<String> _categories = <String>[
    '',
    'Medicines',
    'Medical Devices',
    'Health Essentials',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
    _scrollController.addListener(_handleScroll);
    _loadProducts(reset: true);
    _loadCart();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_handleSearchChange)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      _loadProducts(reset: true);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loadingProducts ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final trigger = _scrollController.position.maxScrollExtent - 180;
    if (_scrollController.position.pixels >= trigger) {
      _loadProducts(reset: false);
    }
  }

  String _productId(Map<String, dynamic> product) =>
      (product['id'] ?? product['_id'] ?? '').toString().trim();

  int _qtyForProduct(String productId) {
    for (final item in _cartItems) {
      if ((item['productId'] ?? '').toString().trim() == productId) {
        return int.tryParse((item['quantity'] ?? '0').toString()) ?? 0;
      }
    }
    return 0;
  }

  Map<String, dynamic>? _cartEntryForProduct(String productId) {
    for (final item in _cartItems) {
      if ((item['productId'] ?? '').toString().trim() == productId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _loadProducts({required bool reset}) async {
    if (reset) {
      if (mounted) {
        setState(() {
          _loadingProducts = true;
          _loadingMore = false;
          _error = '';
          _page = 1;
          _hasMore = true;
        });
      }
    } else {
      if (!_hasMore || _loadingMore) return;
      if (mounted) {
        setState(() {
          _loadingMore = true;
        });
      }
    }

    final nextPage = reset ? 1 : _page + 1;
    final result = await ApiService.fetchStoreProducts(
      search: _searchController.text.trim(),
      category: _category,
      minRating: _minRating > 0 ? _minRating : null,
      sort: _sort,
      page: nextPage,
      limit: 20,
    );

    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _loadingProducts = false;
        _loadingMore = false;
        _error = (result['message'] ?? 'Unable to load products').toString();
      });
      return;
    }

    final fetched = (result['products'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
    final pagination = (result['pagination'] is Map)
        ? (result['pagination'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final totalPages =
        int.tryParse((pagination['totalPages'] ?? '').toString()) ?? 1;

    setState(() {
      _products = reset ? fetched : [..._products, ...fetched];
      _page = nextPage;
      _hasMore = nextPage < totalPages && fetched.isNotEmpty;
      _loadingProducts = false;
      _loadingMore = false;
      _error = '';
    });
  }

  Future<void> _loadCart() async {
    if (mounted) {
      setState(() {
        _loadingCart = true;
      });
    }

    final result = await ApiService.fetchStoreCart();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _cartItems = <Map<String, dynamic>>[];
        _cartTotals = const {'itemCount': 0, 'subtotal': 0};
        _loadingCart = false;
      });
      return;
    }

    final cart = (result['cart'] is Map)
        ? (result['cart'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final items = (cart['items'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
    final totals = (cart['totals'] is Map)
        ? (cart['totals'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{'itemCount': 0, 'subtotal': 0};

    setState(() {
      _cartItems = items;
      _cartTotals = totals;
      _loadingCart = false;
    });
  }

  String _inr(dynamic value) {
    final amount = double.tryParse((value ?? '0').toString()) ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  Widget _buildQtyIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _changeQty(Map<String, dynamic> product, int delta) async {
    if (_mutatingCart || delta == 0) return;
    final productId = _productId(product);
    if (productId.isEmpty) return;

    setState(() {
      _mutatingCart = true;
    });

    final existing = _cartEntryForProduct(productId);
    Map<String, dynamic> response;
    if (existing == null) {
      if (delta < 0) {
        setState(() {
          _mutatingCart = false;
        });
        return;
      }
      response = await ApiService.addStoreCartItem(productId: productId);
    } else {
      final itemId = (existing['itemId'] ?? '').toString().trim();
      final currentQty =
          int.tryParse((existing['quantity'] ?? '0').toString()) ?? 0;
      final nextQty = currentQty + delta;
      if (nextQty <= 0) {
        response = await ApiService.removeStoreCartItem(itemId: itemId);
      } else {
        response = await ApiService.updateStoreCartItem(
          itemId: itemId,
          quantity: nextQty,
        );
      }
    }

    await _loadCart();
    if (!mounted) return;
    setState(() {
      _mutatingCart = false;
    });

    if (response['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (response['message'] ?? 'Unable to update cart').toString(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCartSheet() async {
    await _loadCart();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _CartSheet(
          cartItems: _cartItems,
          cartTotals: _cartTotals,
          mutatingCart: _mutatingCart,
          inr: _inr,
          onChangeQty: (mapped, delta) => _changeQty(mapped, delta),
          onCheckout: () async {
            Navigator.pop(context);
            await _openCheckoutFlow();
          },
        );
      },
    );
  }

  Future<void> _openCheckoutFlow() async {
    if (_cartItems.isEmpty) return;
    final placed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckoutFlowPage(
          cartItems: List<Map<String, dynamic>>.from(_cartItems),
          cartTotals: _cartTotals,
          inr: _inr,
        ),
      ),
    );
    if (placed == true) {
      await _loadCart();
    }
  }

  void _openOrderHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
    );
  }

  Widget _buildFilters() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search medicines, devices, essentials...',
            hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.primary, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final value = _categories[index];
              final selected = value == _category;
              return ChoiceChip(
                label: Text(value.isEmpty ? 'All' : value),
                selected: selected,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
                selectedColor: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide(
                  color: selected ? scheme.primary : Colors.transparent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                onSelected: (_) {
                  setState(() {
                    _category = value;
                  });
                  _loadProducts(reset: true);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Sort + Min rating row with 45-10-45 proportional spacing.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 45,
              child: _buildDropdownField<String>(
                label: 'Sort',
                value: _sort,
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(
                    value: 'price_asc',
                    child: Text('Price: Low to High'),
                  ),
                  DropdownMenuItem(
                    value: 'price_desc',
                    child: Text('Price: High to Low'),
                  ),
                  DropdownMenuItem(
                    value: 'rating_desc',
                    child: Text('Top Rated'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _sort = value;
                  });
                  _loadProducts(reset: true);
                },
              ),
            ),
            const Expanded(flex: 10, child: SizedBox.shrink()),
            Expanded(
              flex: 45,
              child: _buildDropdownField<double>(
                label: 'Min Rating',
                value: _minRating,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Any')),
                  DropdownMenuItem(value: 3, child: Text('3.0+')),
                  DropdownMenuItem(value: 4, child: Text('4.0+')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _minRating = value;
                  });
                  _loadProducts(reset: true);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant, size: 20),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = _productId(product);
    final name = (product['name'] ?? 'Product').toString();
    final description =
        (product['shortDescription'] ?? product['description'] ?? '')
            .toString();
    final rating = double.tryParse((product['rating'] ?? '0').toString()) ?? 0;
    final ratingCount =
        int.tryParse((product['ratingCount'] ?? '0').toString()) ?? 0;
    final mrp = double.tryParse((product['mrp'] ?? '0').toString()) ?? 0;
    final sellingPrice =
        double.tryParse((product['sellingPrice'] ?? '0').toString()) ?? 0;
    final hasDiscount = mrp > sellingPrice && mrp > 0;
    final discountPercent =
        hasDiscount ? (((mrp - sellingPrice) / mrp) * 100).round() : 0;
    final qty = _qtyForProduct(id);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openProductDetail(product),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 88,
                      height: 88,
                      color: scheme.surfaceContainerHighest,
                      child: _buildProductImage(product),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$discountPercent% off',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (rating > 0)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.star_rounded, color: Colors.white, size: 11),
                              ],
                            ),
                          ),
                          if (ratingCount > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($ratingCount)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Text(
                        'New arrival',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _inr(sellingPrice),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            _inr(mrp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description.isEmpty
                          ? 'No description provided'
                          : description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: qty <= 0
                          ? SizedBox(
                              key: const ValueKey('add'),
                              height: 34,
                              child: OutlinedButton.icon(
                                onPressed: _mutatingCart
                                    ? null
                                    : () {
                                        _changeQty(product, 1);
                                      },
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: scheme.primary,
                                  side: BorderSide(color: scheme.primary, width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                                label: const Text(
                                  'Add to cart',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('stepper'),
                              height: 34,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildQtyIconButton(
                                    onPressed: _mutatingCart
                                        ? null
                                        : () {
                                            _changeQty(product, -1);
                                          },
                                    icon: Icons.remove_rounded,
                                    color: scheme.onPrimary,
                                  ),
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '$qty',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: scheme.onPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _buildQtyIconButton(
                                    onPressed: _mutatingCart
                                        ? null
                                        : () {
                                            _changeQty(product, 1);
                                          },
                                    icon: Icons.add_rounded,
                                    color: scheme.onPrimary,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProductDetail(Map<String, dynamic> product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: product,
          qty: _qtyForProduct(_productId(product)),
          mutatingCart: _mutatingCart,
          inr: _inr,
          onChangeQty: (delta) => _changeQty(product, delta),
          buildImage: () => _buildProductImage(product),
        ),
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final media = product['media'];
    final mediaMap = media is Map ? media : const <dynamic, dynamic>{};
    final images = mediaMap['images'];
    final firstMediaImage = images is List && images.isNotEmpty
        ? images.first?.toString().trim() ?? ''
        : '';
    final rawImage = <dynamic>[
      product['imageUrl'],
      mediaMap['thumbnail'],
      firstMediaImage,
    ]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    if (rawImage.isEmpty) return const Icon(Icons.medication_rounded);

    if (rawImage.startsWith('data:image/')) {
      final commaIndex = rawImage.indexOf(',');
      if (commaIndex > 0 &&
          rawImage.substring(0, commaIndex).toLowerCase().contains(';base64')) {
        try {
          final bytes = base64Decode(rawImage.substring(commaIndex + 1));
          return Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported_rounded),
          );
        } catch (_) {
          return const Icon(Icons.image_not_supported_rounded);
        }
      }
      return const Icon(Icons.image_not_supported_rounded);
    }

    final imageUrl = ApiService.resolveMediaUrl(rawImage);
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.image_not_supported_rounded);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.image_not_supported_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cartCount =
        int.tryParse((_cartTotals['itemCount'] ?? '0').toString()) ?? 0;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Medical Store'),
        actions: [
          IconButton(
            tooltip: 'Order history',
            onPressed: _openOrderHistory,
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _loadingCart ? null : _openCartSheet,
                icon: const Icon(Icons.shopping_cart_rounded),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$cartCount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProducts(reset: true);
          await _loadCart();
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _buildFilters(),
            const SizedBox(height: 14),
            if (_loadingProducts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Text(
                      _error,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        _loadProducts(reset: true);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: Text('No products found.')),
              )
            else
              ..._products.map(_buildProductCard),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _cartItems.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_cartTotals['itemCount'] ?? 0} item(s)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _inr(_cartTotals['subtotal']),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _openCheckoutFlow,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Proceed to Buy',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cart bottom sheet
// ---------------------------------------------------------------------------

class _CartSheet extends StatelessWidget {
  const _CartSheet({
    required this.cartItems,
    required this.cartTotals,
    required this.mutatingCart,
    required this.inr,
    required this.onChangeQty,
    required this.onCheckout,
  });

  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic> cartTotals;
  final bool mutatingCart;
  final String Function(dynamic) inr;
  final void Function(Map<String, dynamic> mapped, int delta) onChangeQty;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Cart (${cartTotals['itemCount'] ?? 0})',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            if (cartItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Your cart is empty.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cartItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 18),
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final quantity =
                        int.tryParse((item['quantity'] ?? '1').toString()) ?? 1;
                    final name = (item['name'] ?? 'Product').toString();
                    final lineTotal = double.tryParse(
                            (item['unitPrice'] ?? '0').toString()) ??
                        0;
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${inr(lineTotal)} each',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: mutatingCart
                                    ? null
                                    : () {
                                        final mapped = {
                                          'id': item['productId'],
                                          'productId': item['productId'],
                                        };
                                        onChangeQty(mapped, -1);
                                      },
                                icon: const Icon(Icons.remove_rounded, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                              ),
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '$quantity',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                onPressed: mutatingCart
                                    ? null
                                    : () {
                                        final mapped = {
                                          'id': item['productId'],
                                          'productId': item['productId'],
                                        };
                                        onChangeQty(mapped, 1);
                                      },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    inr(cartTotals['subtotal']),
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: cartItems.isEmpty ? null : onCheckout,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Proceed to Buy',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product detail page
// ---------------------------------------------------------------------------

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.qty,
    required this.mutatingCart,
    required this.inr,
    required this.onChangeQty,
    required this.buildImage,
  });

  final Map<String, dynamic> product;
  final int qty;
  final bool mutatingCart;
  final String Function(dynamic) inr;
  final void Function(int delta) onChangeQty;
  final Widget Function() buildImage;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.qty;
  }

  @override
  void didUpdateWidget(covariant ProductDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final product = widget.product;
    final name = (product['name'] ?? 'Product').toString();
    final description =
        (product['fullDescription'] ?? product['shortDescription'] ?? product['description'] ?? '')
            .toString();
    final rating = double.tryParse((product['rating'] ?? '0').toString()) ?? 0;
    final ratingCount = int.tryParse((product['ratingCount'] ?? '0').toString()) ?? 0;
    final mrp = double.tryParse((product['mrp'] ?? '0').toString()) ?? 0;
    final sellingPrice = double.tryParse((product['sellingPrice'] ?? '0').toString()) ?? 0;
    final hasDiscount = mrp > sellingPrice && mrp > 0;
    final category = (product['category'] ?? '').toString();
    final brand = (product['brand'] ?? '').toString();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Product Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 220,
                height: 220,
                color: scheme.surfaceContainerHighest,
                child: widget.buildImage(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            name,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (brand.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('by $brand', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          if (rating > 0)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.star_rounded, color: Colors.white, size: 13),
                    ],
                  ),
                ),
                if (ratingCount > 0) ...[
                  const SizedBox(width: 8),
                  Text('$ratingCount ratings', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.inr(sellingPrice),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 8),
                Text(
                  widget.inr(mrp),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(((mrp - sellingPrice) / mrp) * 100).round()}% off',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Free delivery available', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'About this item',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            boxShadow: [
              BoxShadow(color: scheme.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3)),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _qty <= 0
                ? SizedBox(
                    key: const ValueKey('add'),
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: widget.mutatingCart
                          ? null
                          : () {
                              widget.onChangeQty(1);
                              setState(() => _qty = 1);
                            },
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                : Row(
                    key: const ValueKey('stepper'),
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: widget.mutatingCart
                                  ? null
                                  : () {
                                      widget.onChangeQty(-1);
                                      setState(() => _qty = (_qty - 1).clamp(0, 999));
                                    },
                              icon: Icon(Icons.remove_rounded, color: scheme.onPrimary),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$_qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                            IconButton(
                              onPressed: widget.mutatingCart
                                  ? null
                                  : () {
                                      widget.onChangeQty(1);
                                      setState(() => _qty += 1);
                                    },
                              icon: Icon(Icons.add_rounded, color: scheme.onPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Continue Shopping', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Checkout flow: Address -> Payment method -> Review & Pay
// ---------------------------------------------------------------------------

enum _CheckoutStep { address, payment, review }

class CheckoutFlowPage extends StatefulWidget {
  const CheckoutFlowPage({
    super.key,
    required this.cartItems,
    required this.cartTotals,
    required this.inr,
  });

  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic> cartTotals;
  final String Function(dynamic) inr;

  @override
  State<CheckoutFlowPage> createState() => _CheckoutFlowPageState();
}

class _CheckoutFlowPageState extends State<CheckoutFlowPage> {
  _CheckoutStep _step = _CheckoutStep.address;

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _paymentMethod = 'upi';
  bool _submitting = false;
  String _error = '';

  static const double _gstRate = 0.18;
  static const double _deliveryCharge = 40;
  static const double _freeDeliveryThreshold = 599;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _subtotal =>
      double.tryParse((widget.cartTotals['subtotal'] ?? '0').toString()) ?? 0;
  double get _gst => double.parse((_subtotal * _gstRate).toStringAsFixed(2));
  double get _deliveryFee => _subtotal >= _freeDeliveryThreshold ? 0 : _deliveryCharge;
  double get _total => _subtotal + _gst + _deliveryFee;

  void _goToStep(_CheckoutStep step) {
    setState(() => _step = step);
  }

  bool _validateAddress() {
    return _formKey.currentState?.validate() ?? false;
  }

  Future<void> _placeOrder() async {
    setState(() {
      _submitting = true;
      _error = '';
    });

    // Simulate a real payment gateway round-trip.
    final placed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentProcessingPage(
          amount: _total,
          paymentMethod: _paymentMethod,
          onProcess: () => ApiService.createStoreOrder(
            delivery: {
              'fullName': _fullName.text.trim(),
              'phone': _phone.text.trim(),
              'addressLine1': _addressLine1.text.trim(),
              'addressLine2': _addressLine2.text.trim(),
              'city': _city.text.trim(),
              'state': _state.text.trim(),
              'pincode': _pincode.text.trim(),
              'notes': _notes.text.trim(),
            },
            paymentMethod: _paymentMethod,
          ),
        ),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
    });

    if (placed == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == _CheckoutStep.address) {
              Navigator.of(context).pop();
            } else {
              _goToStep(_CheckoutStep.values[_step.index - 1]);
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildStepper(scheme),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: switch (_step) {
                _CheckoutStep.address => _buildAddressStep(key: const ValueKey('address')),
                _CheckoutStep.payment => _buildPaymentStep(key: const ValueKey('payment')),
                _CheckoutStep.review => _buildReviewStep(key: const ValueKey('review')),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(ColorScheme scheme) {
    final labels = const ['Address', 'Payment', 'Review'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final leftDone = (index - 1) ~/ 2 < _step.index;
            return Expanded(
              child: Container(
                height: 2,
                color: leftDone ? scheme.primary : scheme.outlineVariant,
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == _step.index;
          final isDone = stepIndex < _step.index;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isActive ? scheme.primary : scheme.surfaceContainerHighest,
                  border: Border.all(
                    color: isActive ? scheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[stepIndex],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildAddressStep({required Key key}) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Address',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Where should we deliver your order?',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _field(_fullName, 'Full Name', required: true),
            _field(_phone, 'Phone Number', required: true, keyboardType: TextInputType.phone),
            _field(_addressLine1, 'Address Line 1', required: true),
            _field(_addressLine2, 'Address Line 2 (optional)', required: false),
            Row(
              children: [
                Expanded(child: _field(_city, 'City', required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_state, 'State', required: true)),
              ],
            ),
            _field(_pincode, 'Pincode', required: true, keyboardType: TextInputType.number),
            _field(_notes, 'Delivery Notes (optional)', required: false, maxLines: 2),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  if (_validateAddress()) {
                    _goToStep(_CheckoutStep.payment);
                  }
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue to Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required bool required,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: required
            ? (value) => (value == null || value.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildPaymentStep({required Key key}) {
    final scheme = Theme.of(context).colorScheme;
    final methods = const [
      ('upi', 'UPI', Icons.qr_code_2_rounded, 'Pay via Google Pay, PhonePe, Paytm & more'),
      ('card', 'Credit / Debit Card', Icons.credit_card_rounded, 'Visa, Mastercard, RuPay & more'),
      ('netbanking', 'Net Banking', Icons.account_balance_rounded, 'All major banks supported'),
      ('wallet', 'Wallet', Icons.account_balance_wallet_rounded, 'Paytm, Amazon Pay & more'),
      ('cod', 'Cash on Delivery', Icons.local_shipping_rounded, 'Pay when your order arrives'),
    ];

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how you\'d like to pay',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ...methods.map((entry) {
            final (value, label, icon, subtitle) = entry;
            final selected = _paymentMethod == value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _paymentMethod = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: selected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => _goToStep(_CheckoutStep.review),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue to Review', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep({required Key key}) {
    final scheme = Theme.of(context).colorScheme;
    final methodLabels = const {
      'upi': 'UPI',
      'card': 'Credit / Debit Card',
      'netbanking': 'Net Banking',
      'wallet': 'Wallet',
      'cod': 'Cash on Delivery',
    };

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Pay',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            scheme: scheme,
            title: 'Delivering to',
            trailing: TextButton(
              onPressed: () => _goToStep(_CheckoutStep.address),
              child: const Text('Change'),
            ),
            child: Text(
              '${_fullName.text}\n${_addressLine1.text}${_addressLine2.text.isNotEmpty ? ', ${_addressLine2.text}' : ''}\n'
              '${_city.text}, ${_state.text} - ${_pincode.text}\nPhone: ${_phone.text}',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            scheme: scheme,
            title: 'Payment Method',
            trailing: TextButton(
              onPressed: () => _goToStep(_CheckoutStep.payment),
              child: const Text('Change'),
            ),
            child: Text(
              methodLabels[_paymentMethod] ?? _paymentMethod,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            scheme: scheme,
            title: 'Order Summary (${widget.cartItems.length} item(s))',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...widget.cartItems.map((item) {
                  final quantity = int.tryParse((item['quantity'] ?? '1').toString()) ?? 1;
                  final name = (item['name'] ?? 'Product').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$name x$quantity',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                _priceRow('Subtotal', widget.inr(_subtotal), scheme),
                _priceRow('GST (18%)', widget.inr(_gst), scheme),
                _priceRow(
                  'Delivery',
                  _deliveryFee == 0 ? 'FREE' : widget.inr(_deliveryFee),
                  scheme,
                  valueColor: _deliveryFee == 0 ? Colors.green : null,
                ),
                const Divider(height: 20),
                _priceRow('Total Amount', widget.inr(_total), scheme, bold: true),
              ],
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _placeOrder,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                _submitting ? 'Processing...' : 'Pay ${widget.inr(_total)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                '100% Secure Payments',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required ColorScheme scheme,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, ColorScheme scheme, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? (bold ? scheme.onSurface : scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment processing (simulated gateway) + success/failure animation
// ---------------------------------------------------------------------------

class PaymentProcessingPage extends StatefulWidget {
  const PaymentProcessingPage({
    super.key,
    required this.amount,
    required this.paymentMethod,
    required this.onProcess,
  });

  final double amount;
  final String paymentMethod;
  final Future<Map<String, dynamic>> Function() onProcess;

  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

enum _PaymentPhase { processing, success, failure }

class _PaymentProcessingPageState extends State<PaymentProcessingPage>
    with SingleTickerProviderStateMixin {
  _PaymentPhase _phase = _PaymentPhase.processing;
  String _message = '';
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _run();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    // Give the "gateway" a moment to feel real before resolving.
    final results = await Future.wait([
      widget.onProcess(),
      Future.delayed(const Duration(milliseconds: 1400)),
    ]);
    final response = results[0] as Map<String, dynamic>;
    if (!mounted) return;

    if (response['success'] == true) {
      setState(() => _phase = _PaymentPhase.success);
      SchedulerBinding.instance.addPostFrameCallback((_) {});
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _phase = _PaymentPhase.failure;
        _message = (response['message'] ?? 'Payment failed. Please try again.').toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _phase != _PaymentPhase.processing,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: switch (_phase) {
                _PaymentPhase.processing => _buildProcessing(scheme),
                _PaymentPhase.success => _buildSuccess(scheme),
                _PaymentPhase.failure => _buildFailure(scheme),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing(ColorScheme scheme) {
    return Column(
      key: const ValueKey('processing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _spinController,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [scheme.primary.withValues(alpha: 0.05), scheme.primary],
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Processing Payment',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Please wait, do not close this screen',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '₹${widget.amount.toStringAsFixed(2)} via ${widget.paymentMethod.toUpperCase()}',
            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(ColorScheme scheme) {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _SuccessCheckmark(color: Colors.green.shade600),
        const SizedBox(height: 26),
        Text(
          'Payment Successful',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '₹${widget.amount.toStringAsFixed(2)} paid successfully',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'Your order has been placed',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _buildFailure(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        key: const ValueKey('failure'),
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.error.withValues(alpha: 0.12)),
              child: Icon(Icons.close_rounded, color: scheme.error, size: 44),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Payment Failed',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCheckmark extends StatefulWidget {
  const _SuccessCheckmark({required this.color});

  final Color color;

  @override
  State<_SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<_SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleScale;
  late final Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _circleScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.elasticOut),
    );
    _checkProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _circleScale.value,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                child: CustomPaint(
                  painter: _CheckmarkPainter(progress: _checkProgress.value, color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p1 = Offset(size.width * 0.28, size.height * 0.52);
    final p2 = Offset(size.width * 0.44, size.height * 0.68);
    final p3 = Offset(size.width * 0.74, size.height * 0.34);

    final firstLegLength = (p2 - p1).distance;
    final secondLegLength = (p3 - p2).distance;
    final totalLength = firstLegLength + secondLegLength;
    final drawLength = totalLength * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawLength <= firstLegLength) {
      final t = firstLegLength == 0 ? 0 : drawLength / firstLegLength;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.lineTo(p2.dx, p2.dy);
      final remaining = drawLength - firstLegLength;
      final t = secondLegLength == 0 ? 0 : remaining / secondLegLength;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Order history page (patient-facing transactions)
// ---------------------------------------------------------------------------

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _orders = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.fetchStoreOrders();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = (result['message'] ?? 'Unable to load orders').toString();
      });
      return;
    }
    final orders = (result['orders'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
    setState(() {
      _orders = orders;
      _loading = false;
      _error = '';
    });
  }

  String _inr(dynamic value) {
    final amount = double.tryParse((value ?? '0').toString()) ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return Colors.green.shade700;
      case 'CANCELLED':
        return scheme.error;
      case 'SHIPPED':
        return Colors.blue.shade700;
      case 'PROCESSING':
        return Colors.orange.shade700;
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Your Orders')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            Text(_error, style: TextStyle(color: scheme.error)),
                            const SizedBox(height: 10),
                            FilledButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ],
                  )
                : _orders.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          Icon(Icons.receipt_long_outlined, size: 56, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'No orders yet',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final items = (order['items'] as List? ?? const <dynamic>[])
                              .whereType<Map>()
                              .toList(growable: false);
                          final totals = (order['totals'] is Map)
                              ? order['totals'] as Map
                              : const <String, dynamic>{};
                          final status = (order['status'] ?? 'PLACED').toString();
                          final paymentStatus = (order['paymentStatus'] ?? '').toString();
                          final paymentMethod = (order['paymentMethod'] ?? '').toString();
                          final orderId = (order['_id'] ?? '').toString();
                          final createdAt = (order['createdAt'] ?? '').toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      orderId.isEmpty
                                          ? 'Order'
                                          : '#${orderId.substring(orderId.length > 8 ? orderId.length - 8 : 0).toUpperCase()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status, scheme).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: _statusColor(status, scheme),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...items.take(3).map((item) {
                                  final name = (item['name'] ?? 'Product').toString();
                                  final qty = (item['quantity'] ?? 1).toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      '$name x$qty',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }),
                                if (items.length > 3)
                                  Text(
                                    '+${items.length - 3} more item(s)',
                                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                                  ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _inr(totals['total'] ?? totals['subtotal']),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                        ),
                                        Text(
                                          '${paymentMethod.toUpperCase()} · $paymentStatus',
                                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
