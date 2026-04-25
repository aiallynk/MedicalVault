import 'dart:async';

import 'package:flutter/material.dart';

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
    return 'INR ${amount.toStringAsFixed(2)}';
  }

  Widget _buildQtyIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      visualDensity: VisualDensity.compact,
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
        ),
      );
    }
  }

  Future<void> _openCheckout() async {
    final fullName = TextEditingController();
    final phone = TextEditingController();
    final addressLine1 = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController();
    final pincode = TextEditingController();
    final notes = TextEditingController();

    bool submitting = false;
    String error = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Basic Checkout'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fullName,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    TextField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    TextField(
                      controller: addressLine1,
                      decoration:
                          const InputDecoration(labelText: 'Address Line 1'),
                    ),
                    TextField(
                      controller: city,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    TextField(
                      controller: state,
                      decoration: const InputDecoration(labelText: 'State'),
                    ),
                    TextField(
                      controller: pincode,
                      decoration: const InputDecoration(labelText: 'Pincode'),
                    ),
                    TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(error, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                            error = '';
                          });
                          final response = await ApiService.createStoreOrder(
                            delivery: {
                              'fullName': fullName.text.trim(),
                              'phone': phone.text.trim(),
                              'addressLine1': addressLine1.text.trim(),
                              'city': city.text.trim(),
                              'state': state.text.trim(),
                              'pincode': pincode.text.trim(),
                              'notes': notes.text.trim(),
                            },
                          );
                          if (!mounted) return;
                          if (response['success'] == true) {
                            Navigator.pop(context);
                            await _loadCart();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Order placed successfully'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            submitting = false;
                            error = (response['message'] ?? 'Checkout failed')
                                .toString();
                          });
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Place Order'),
                ),
              ],
            );
          },
        );
      },
    );

    fullName.dispose();
    phone.dispose();
    addressLine1.dispose();
    city.dispose();
    state.dispose();
    pincode.dispose();
    notes.dispose();
  }

  Future<void> _openCartSheet() async {
    await _loadCart();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cart (${_cartTotals['itemCount'] ?? 0})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                if (_cartItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Your cart is empty.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _cartItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 14),
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        final quantity = int.tryParse(
                                (item['quantity'] ?? '1').toString()) ??
                            1;
                        final name = (item['name'] ?? 'Product').toString();
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
                                    _inr(item['unitPrice']),
                                    style:
                                        const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            _buildQtyIconButton(
                              onPressed: _mutatingCart
                                  ? null
                                  : () {
                                      final mapped = {
                                        'id': item['productId'],
                                        'productId': item['productId'],
                                      };
                                      _changeQty(mapped, -1);
                                    },
                              icon: Icons.remove_circle_outline,
                            ),
                            Text('$quantity'),
                            _buildQtyIconButton(
                              onPressed: _mutatingCart
                                  ? null
                                  : () {
                                      final mapped = {
                                        'id': item['productId'],
                                        'productId': item['productId'],
                                      };
                                      _changeQty(mapped, 1);
                                    },
                              icon: Icons.add_circle_outline,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Subtotal: ${_inr(_cartTotals['subtotal'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _cartItems.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _openCheckout();
                          },
                    child: const Text('Checkout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
              return ChoiceChip(
                label: Text(value.isEmpty ? 'All' : value),
                selected: value == _category,
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
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;

            final sortField = DropdownButtonFormField<String>(
              value: _sort,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Sort',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              selectedItemBuilder: (context) => const [
                Text('Newest', overflow: TextOverflow.ellipsis),
                Text('Price Up', overflow: TextOverflow.ellipsis),
                Text('Price Down', overflow: TextOverflow.ellipsis),
                Text('Top Rated', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest')),
                DropdownMenuItem(
                  value: 'price_asc',
                  child: Text('Price Low to High'),
                ),
                DropdownMenuItem(
                  value: 'price_desc',
                  child: Text('Price High to Low'),
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
            );

            final ratingField = DropdownButtonFormField<double>(
              value: _minRating,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Min Rating',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
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
            );

            if (compact) {
              return Column(
                children: [
                  sortField,
                  const SizedBox(height: 10),
                  ratingField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: sortField),
                const SizedBox(width: 10),
                Expanded(child: ratingField),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final id = _productId(product);
    final name = (product['name'] ?? 'Product').toString();
    final description =
        (product['shortDescription'] ?? product['description'] ?? '')
            .toString();
    final image = (product['imageUrl'] ?? '').toString().trim();
    final rating = double.tryParse((product['rating'] ?? '0').toString()) ?? 0;
    final qty = _qtyForProduct(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 84,
                height: 84,
                color: Colors.grey.shade100,
                child: image.isEmpty
                    ? const Icon(Icons.medication_rounded)
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_rounded),
                      ),
              ),
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
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _inr(product['sellingPrice']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rating > 0 ? 'Rating ${rating.toStringAsFixed(1)}' : 'New',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description.isEmpty
                        ? 'No description provided'
                        : description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  if (qty <= 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: _mutatingCart
                            ? null
                            : () {
                                _changeQty(product, 1);
                              },
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('Add to cart'),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildQtyIconButton(
                          onPressed: _mutatingCart
                              ? null
                              : () {
                                  _changeQty(product, -1);
                                },
                          icon: Icons.remove_circle_outline,
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        _buildQtyIconButton(
                          onPressed: _mutatingCart
                              ? null
                              : () {
                                  _changeQty(product, 1);
                                },
                          icon: Icons.add_circle_outline,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount =
        int.tryParse((_cartTotals['itemCount'] ?? '0').toString()) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Store'),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _loadingCart ? null : _openCartSheet,
                icon: const Icon(Icons.shopping_cart_rounded),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
                    Text(_error, style: const TextStyle(color: Colors.red)),
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
    );
  }
}
