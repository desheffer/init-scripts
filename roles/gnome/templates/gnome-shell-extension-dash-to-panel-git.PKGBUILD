# $Id$
# Maintainer: Mohammadreza Abdollahzadeh < morealaz at gmail dot com >
# Contributor: Carl George < arch at cgtx dot us >

pkgname=gnome-shell-extension-dash-to-panel-git
_commit=fbfa5a1
pkgver=41.r2.${_fbfa5a1}
pkgrel=1
pkgdesc='Extension for GNOME shell to combine the dash and main panel'
arch=(any)
_githubname=dash-to-panel
_githubowner=philippun1
_githubtree=update-to-gnome40
url="https://github.com/${_githubowner}/${_githubname}"
license=(GPL2)
depends=('gnome-shell>=4.0')
makedepends=('git' 'gnome-common' 'intltool')
provides=("${pkgname%-git}")
conflicts=("${pkgname%-git}")
source=("git+${url}.git#commit=${_commit}")
sha256sums=('SKIP')

build() {
  cd "${srcdir}/${_githubname}"
  make _build
}

package() {
  cd "${srcdir}/${_githubname}"
  make DESTDIR="$pkgdir" install
}