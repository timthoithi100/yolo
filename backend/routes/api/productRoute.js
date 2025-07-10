const express = require('express')
const router = express.Router();

// Product Model
const Product = require('../../models/Products');

// @route GET /products
// @desc Get ALL products
router.get('/', (req,res)=>{
    console.log('GET /api/products received');
    // Fetch all products from database
    Product.find({}, (error, products)=>{
        if (error) {
            console.error('Error fetching products:', error);
            res.status(500).json({ success: false, message: 'Error fetching products', error: error.message });
        } else {
            console.log('Fetched products:', products.length, 'items');
            res.json(products);
        }
    });
});

// @route POST /products
// @desc  Create a product
router.post('/', (req,res)=>{
    console.log('POST /api/products received. Request Body:', req.body);

    // Create a product item
    const newProduct = new Product({
        name: req.body.name,
        description: req.body.description,
        price: req.body.price,
        quantity: req.body.quantity,
        // photo: req.body.photo // Ensure photo is also passed if needed, based on frontend form
    });

    newProduct.save((err, product)=>{
        if (err) {
            console.error('Error saving new product:', err);
            res.status(500).json({ success: false, message: 'Error saving product', error: err.message });
        } else {
            console.log('New product saved successfully:', product);
            res.status(201).json(product); // Send 201 Created status
        }
    });
});

// @route PUT api/products/:id
// @desc  Update a product
router.put('/:id', (req,res)=>{
    console.log(`PUT /api/products/${req.params.id} received. Request Body:`, req.body);
    // Update a product in the database
    Product.updateOne({_id:req.params.id},{
        name: req.body.name,
        description: req.body.description,
        price: req.body.price,
        quantity: req.body.quantity,
        photo:req.body.photo
    }, {upsert: true}, (err, result)=>{ // Added result to callback
        if(err) {
            console.error('Error updating product:', err);
            res.status(500).json({ success: false, message: 'Error updating product', error: err.message });
        } else {
            console.log('Product updated successfully:', result);
            res.json({success:true, message: 'Product updated'});
        }
    });
});

// @route DELETE api/products/:id
// @desc  Delete a product
router.delete('/:id', (req,res)=>{
    console.log(`DELETE /api/products/${req.params.id} received`);
    // Delete a product from database
    Product.deleteOne({_id: req.params.id}, (err)=>{
        if (err){
            console.error('Error deleting product:', err);
            res.status(500).json({success:false, message: 'Error deleting product', error: err.message});
        }else{
            console.log('Product deleted successfully');
            res.json({success:true, message: 'Product deleted'});
        }
    });
});

module.exports = router;
