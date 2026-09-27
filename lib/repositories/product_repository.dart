import '../database/database_helper.dart';
import '../models/product_model.dart';
import '../models/product_sale_unit_model.dart';

class ProductRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<List<Product>> getProducts() async {
    return await _databaseHelper.getProducts();
  }

  Future<List<Product>> searchProducts({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    return await _databaseHelper.searchProducts(
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Product>> getProductsWithImages({
    int limit = 20,
    int offset = 0,
  }) async {
    return await _databaseHelper.getProductsWithImages(
      limit: limit,
      offset: offset,
    );
  }

  Future<void> addProduct(Product product) async {
    product.id = await _databaseHelper.insertProduct(product);
  }

  Future<void> updateProduct(Product product) async {
    await _databaseHelper.updateProduct(product);
  }

  Future<void> deleteProduct(int id) async {
    await _databaseHelper.deleteProduct(id);
  }

  Future<void> clearProducts() async {
    await _databaseHelper.clearProducts();
  }

  // Product Sale Units CRUD operations

  Future<List<ProductSaleUnit>> getSaleUnits(int productId) async {
    final saleUnits = await _databaseHelper.getSaleUnits(productId);
    print('DEBUG: ProductRepository.getSaleUnits - productId: $productId');
    print('DEBUG: ProductRepository.getSaleUnits - saleUnits.length: ${saleUnits.length}');
    print('DEBUG: ProductRepository.getSaleUnits - saleUnits: ${saleUnits.map((u) => u.saleUnit).toList()}');
    return saleUnits;
  }

  Future<void> addSaleUnit(ProductSaleUnit saleUnit) async {
    await _databaseHelper.insertSaleUnit(saleUnit);
  }

  Future<void> updateSaleUnit(ProductSaleUnit saleUnit) async {
    await _databaseHelper.updateSaleUnit(saleUnit);
  }

  Future<void> deleteSaleUnit(int id) async {
    await _databaseHelper.deleteSaleUnit(id);
  }

  Future<void> deleteSaleUnitsByProductId(int productId) async {
    await _databaseHelper.deleteSaleUnitsByProductId(productId);
  }
}
