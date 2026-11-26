'use strict';

const origin = process.env.PRODUCT_IMAGES_ORIGIN ||
  'https://wizz-merchants-staging-businessphotosbucket-up3j1qega8m5.s3.amazonaws.com';

function ownedProductImage(value, businessId) {
  if (typeof value !== 'string') return false;
  const prefix = origin + '/merchants/' + businessId + '/product-images/';
  return value.startsWith(prefix) && /^[A-Za-z0-9_-]+\.(?:jpg|jpeg|png|webp)$/i.test(value.slice(prefix.length));
}

module.exports = { ownedProductImage };
