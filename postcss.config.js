module.exports = {
  plugins: [
    require('postcss-import')({
      path: ['themes/lvzh/assets/css', 'assets/css']
    })
  ]
}