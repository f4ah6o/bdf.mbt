///|
fn pdf_jpx_test_sample() -> Bytes {
  let encoded = [
    "/0//UQApAAEAAACAAAAAgAAAAAAAAAAAAAAAgAAAAIAAAAAAAAAAAAABBwEB/1wADUBASEhQSEhQSEhQ/1IADAABAAEAAwQEAAH/",
    "kAAKAAAAABySAAH/k9+FqJQ2D3ci6vHvB8A/iVx8Ewn4IgoMu51nxwcgnfSVNil7RvvDkRzfPYJ5jscgh6feXaBZStUmhmy5F7zK",
    "A/SJg46wvSl9nCL11kmSp+TkqynU8HYDzLSmZg+cHGSCSTiQOJZyrRDp6/A7HKhtEhNFxTPgDj6kiRQ64A3KkOklWsRyWD4ljr8T",
    "CKARXqtI1FWFsaBQARc5qlZKWrTVlCuaPEwgYnhvNJVspqKZZmdJGB51c1x6JSMLb7i0XMKhrrIovY5iN9QN8xx+SBUizpjseQHI",
    "i62ax9tNR9tJw+2lgIG0Bu5gvpKBxhUtaRMToFyaZxxes1ZnUwZuLxigqGAy/EZ5Cv9QJB9rsIOs+s5wbZ1/e2AqoALl4wkeGrnp",
    "Q0pjPg7HlaJOhLX1NADZXl8jcCuyGnr8tN6dRI/5upwEao/A9jsxl9De33r/EUPUyMjPhmkSNcNzwdnj+QXVJfF3Nq1rmMwfUOX8",
    "B1lgPhN3nvRLEWJodzd7FCKCHSPpL/kCIIGgcFoHhR88Ta7w7BqjnC35YROhx1hEd9+hujDqoC7WDa6YzAJF9Qvz3U11xkZfxlyT",
    "NpLaDxntMHImPn05nHcUoQfI0bMb/pIus/k1mqqp6vHZZqNR4mNwqCOy4btzbCGJ3BHgwNvh6h72j40sa1+0bJM1YRVxQQEX15oc",
    "BDtcMdTJDGNA6QD5AsoziqRU1G3po54miI3OdimAvIpcNBa/z6IQEAJcN8QLhhsomTB3p6RPMAwpewuXP9LDLBMb4R3WOqn66QRC",
    "Qn5Mm01p8shzwSIrfTSvI+pstb83EOGorapbnJSKCsL1vnRrKCHNGyCnMJSc/20gTRG4Jtjkim9X/AELGv2tbp++NkKNEHWAz67y",
    "0Wl3Bo4KhHLB6QXRgRnH279x9u/kPt6DwLsYCH84qFH6o/pEhB9VoiCrso2MOm6UZsR50Mjyu2gzl0+TgdzjveeKAQuIBN3oY6Te",
    "761Pl62nMcm8MWnrJ3d3XpnNEho/ixGCf923+o6bbE+5oR4ZJDQ1nILAGrTYFbJ2r8WwvrgNgU7h+pBj2+S4J1kTI3ROGKNUPSxE",
    "IMEw8xQ12eK8qN2DcaHhkPwfjLieLGICpTq6luwqFrnLToJv1t6kqG4tU29xQW/DqMdp5ZHgObPQLOj3b8zYjixkbO9QwlEfTYp3",
    "EzhwWU38rqSiteuOmH+D1hQV/KWCsCxtXbA/Aj5XVE84ot8miU+rmKgGyd1gm93LWSkjSyLYMZAsqKNR5xdBc2+2DZP4m4uXhvrO",
    "30UhuJSW4NMTBCP9Jt2jBVzBroNRM2e1/K/MM67sLCEZTm12rxi9aOFDI5VTTmxGXzz0/G0/a9bT8BvN8VnGVtHPxyetTu4gDNUi",
    "kZE7xrbsKVIhnKSq+kC71KX8tO1n8pSAqd1zywZaZyQ0Ipytxxjub/APZbehqHpHdh7u/XxBWCxlY14orZ7ukBwSsFUyv8UvKmXx",
    "18kKsSPIN+Rq2BW+BBf7RmeFQbWLhiQrJQyGt6/qWXmOGnmSpT7HFpSNeUtqfq+RZdlTUXPVFebHQtGuRvZOtrFAouijSjXlx6fm",
    "zVBJ2VURC5q3H1rH/z7JYxRqHUAodFh4+2mMLtUNlJs9jPe86d5pYK2dbRA5IseUyWAjt8z3ZiQqkyCnlzuV63vwj2GkeYbV4yfN",
    "kjdsW5aEKse/B/iDjKaVOlhcmPQavSo9J9PLUnuf9liscaw/i5UzdmAQE9o7D0ZAq3hzaGyTiC0ie5Lbzy1QMsx2nmkJCJfkY/Zb",
    "zi2Twy3ij8v2WXWwXrYkzyLSYbmSVxAh56NaxPIXFXF7ZaU+08TpVIBT6qSJUJzn/wmceUXJBmNk7F59mOt/N2JN7GY4fJVwMqOc",
    "K/Gl0I4xHHyF7UvSe3CMwje8QjncdtMpd150nZi7KV4ktBNScWDtMAmK86+It6pcgDxjBRZnNw/V1gXQhFAXgSURQKH/NOPzZ4k4",
    "fN4kZwWbCMSmfNXW4ChpNbX3NCld73hHN+PACNbv6pIoEhx27LbJg7RP3PdMc1pundljIirJdBM4hNxkJB4chY2lPmaiLjcP8Keu",
    "kfRQaqSLBMF3SEAyz8jMFMiHY5nD6RkcKuKldTwA0hhwO+Cg0vUbph16TdFmS6TW4gM60QC/1va0w0GDi+YYJG5dAxtl3PzxrdXj",
    "+9BCOOHcureu6hJxHIka1lDa3J4brQpuZQCoXFd375FW7ATWf5bZlTaAjvBOcyTGtBLl19jkHmRstvMbJkVg88SZtSMIIjUzkaNX",
    "fRbd/3dKP/fgx1FNejF120YM6d8loAzTh3HABl3dNTdjLPvfQTiv0q8YpA/SRzw4T7beMGVz5FqACtx8xCCG+zEACx3K0u/KpB31",
    "HqStwARYMePW3vkAc2yxBG+y7c4eJpIMWnf/Qn60xwLolCjI2OEh3t1XzFHrpzqAtHl5+xkqSH3NVEueg7aIOLuo3dBiR42fdJhQ",
    "DHMv1OurDyOfiat1c0E/L8DWXrLyXxOwxjpFJdmNE++GPmwzxwYRpV+GkDvh0Hvy2hoIDMQ1K7QTrx1Y7T+afzavwKSPYLVRusMV",
    "O3VZwuQvawAftdqg+Y2QP7lZofVWoSHoArfhecaXM969Red/T+6qXm/9Gd8dTOTkzqWo7rq7ovWYrjs5GaTHO4cfygwltwWRMUUR",
    "oM9vF00wBvIye/iD4ZOJ+XOFpFhAcLUi+Tc4u6Cq28RuTe70S16i+EuuBqIlEUUCBRN9y+DopTSlGzD83jkgRsnqRxmv2Es6Zpef",
    "5jjUO3KRBVkV914QvrpPrDXBGeAM3Cfwvn8QcTLmd3gPd0CK/cZSFZba48RBLVW73QAJ1Wdb7o9n5q5i1hoH9dN0C+CPB6rT22hl",
    "ieYSc+xe/kZkXnBm/x0ktSWUIgjuggs5wUIMMWY2TjNadg7s1SumVgUFdmong/AVzrws3qJZqo6fWz4TjEg65wha8c/D2oo+32lY",
    "fb7RgPYMvjqGfN1OnEV2aRj8gYCCV0jJkd/ZsL7cu8tAv8Lem1F20n/ED5XxNTy1nEEiGPCrypkn1iiEu0u2Yv0z1sIK2BvuPNUn",
    "eNtv2c8El9UKChrGJ9stmiWcdNlF+fZ6LB553s31THIoCuGtIckB993m6RP5XTXZs2+rKjmKfTUyPkZsNR/cmqgfoaG16wIJ+e0u",
    "CHBKlYPeuAMWVpaNGSo4bFFu0AvFfcePQZhQ99yNRowI8MKFP3fJtRr9JhPu3/bS1Dpjmw3scmh5Q/it3ZaV8XdcetXhgO7/P6zL",
    "i3P8KQ4rOGNeNinEYIplI+8V9SQHXlYt0mHy8cv3efqer4hPoI/fNMJuUwYxuQyzCcHZOEzRyz4yBvX3b6YOGKK6p7Zph30xY8CF",
    "6qC1EDY2NKSharBE3UWT6BcywHwwsuLmQ4uDTpFVyjuYDrsSMDxztBMFg7tNkalg9+TMrIcJnbLuYKxgGG5siK8j9gN+U7JwT1n6",
    "ji+89UeexESSRFRTHHbjRFe+8Zf0uTVbkQ9NjscGaspUz2zVOGTgDuSYy9mAHrop9vxyUM/1SI64rSC57XUfe6/gqre5tJ11wxrs",
    "Gy6o3HDqSOfVGB2RNthp53tiHZvyauOGo3kQURBJWLNXokpf3zCzdy5BGzCiUln6vp85u7YKTLmI13kjx4VKXhwKZifct9eAonoE",
    "k3tMpa+XYLOSobms2mWv3s3yyXSvhUyuYh+cXnTCyEpJrWzDP9/+T05wE2lQJNJxONusbyBWoSghb6RlBZkTE2FbqnsDW2vymEer",
    "uoIvG7/0UtSnSSPT/aIrh+SJRGWWOs8hhHXHiPTjDTdmr++s6tLHk56sjZZtfywoCLjoD8Y0D4xOZOK8ln0tsfZW23zxTrkr9vWb",
    "a928nwzfaBFJxhbBnGTRhFuVSUepcTh/6U025u/Ig1Pp2tC1Rv73wAmooxkIjLV/yLRh6YrpzzmOz7Pt74ZOgCezcdLzk4so9IrP",
    "4IeBF5omeWWeoDFqH7wV2G6fdabNLH20NP7s7sxI2wJm14e2yy3f+XfyVN0K77lPPev/F2L8w8usbScpur7go8dMo7wzblEgMgZh",
    "yEZcmsKdoqCiT969NmvSFLQR+F79zF7FFS94IFkO5gJTuWh4IkxS/hMDpaaQjGP7WXB4SRBCKektrlz1Uf8GCW3DWLusbeqmvVCE",
    "RJ5S94gsIvtl8SI62t883O2a5NnOTKRjNDtOWvkMfKTpYHjVxn11Zjy/1MUJTv9pHCYFRRb4RqwE7cGcPyJKAL1agfGAI7yPBY5W",
    "Nyu6SKaMhuC2VeEbVkWfHr1gg4aFio9Vg86G9ALSxsE6yGUaEuqlF3VUsAuOStQm/jY4KK2c/LnZVGqTH/x5GPPhL79A7NleJ8Fl",
    "GrjmqIlH9ej2IKvVdYiOz1XQ3RubQ9qADXa73gxkqY4KPk4iXUEy4blA8GsYnT5ErwBES/v2I2NkK9TrcHU12iM9+9h6eJKTwA02",
    "oH4Nv84y9F4gTE9LGrhjk/DqtKTjC3SnC854KE5yUUrxWXKeikdnvyik16nv9OJzAwkKXeizKceTsTE+JZgWUV+F1uHYx3gr/rXd",
    "5CDxhobgMnj2FZxlH9MvfJkk0iEjDPThHwwGjzljUzZDz5pMP73Cpn3sfLkCgGE4wEVhJPxh/sSQT/a7MRidF0M6fJ0OW5SWnoiY",
    "49Th9gID+fieuPAH6Qq6ESWcbVpq5m13h1dSBKXYVtwtICZ1oMxtd7zQ+QMoEvLTum20w/Qr29+InVas+C0LWbc5NoT6dUEICF/w",
    "YBcnNWTvTRuqCNVbZxMrQwCMILJbVL6BUPv/acxklXqwrEobcEJEMVzmam5yssmxtsrBx/VJdrjnglTN6YmQl8LOJayeBAu4Yo88",
    "ZriYX32Rs4cWvyXlxS6PpXYO3O7QG7UB2apZBGSuxeu8ZNHpRTo/HBC8den/W0QlWyeuiQVdHFKlKzOZmOhoLpng2XyQ1pfH9CC+",
    "pP4lFAPMN1lyuo8tOd97UqOPC+8aD53xaiaASjR3kD/Pta+mZfRAc+GN56XONaUsp7ZP/wA1CraSPUJpYp6YVxPhfnZx9SNS+d0k",
    "mqeHMW36Z4OHIwNoezOxExwrgrifzwoj33mKFnGJdMiUPEkbxEoCQaPKpAg6DMfd05dGUgTVgtHGjElt0syjhR+SIwdBb6pMv0YZ",
    "PFbFaIaI+sXtFCOxHi/4lMGaeb4I5n+sYWuz6zf4MleZluCtdD23zKzMYgBj9uPnTsMW2uEKOgxZyTHmjs4zqr3N2aYsKka82kPV",
    "5UnBsdbKNioGoyZFkdbyNFj8avqxso24wnBrghKT7iYbEEisZzFnOZtikyxnQjJKC8PqTtKinNpGjXguDYBJyVycJQ3DGo3BSZzE",
    "V5Z01ZpSnuq5cakV1YRf9UAvLEE/FbVhS1RXm2xW7gp9kUty0MjWqflQDEtdqqyf/WoKhTR4u7TCPfnoeWLjbiHR/02GfelL8aIE",
    "98/RCQYEY7kRSL/8u452haliGDqEfFAeM+ASxnEUtr4+aI7Ig7MI/p/Z6256+BOuFs8xdiC+vUeOwjU/M0QJYSF3nZyIurIa6zV8",
    "W/eZsFYwhuT74p88D5tqk5HLiN3LybKYYwpOLzYNfL6EvlwdoGppRXBueS8l+3pwGYDLupOjk/7i8ph3+uOy7s9CxZ6xL+ZZCH+9",
    "781RsAppNTr9QiLY+nldWTq2J2vZtSF14hWKi9D9QF+++S28qgrci/W8fUf/NS9/qgYiJFXBMou2iE5vSt1U85jhGBQ/uBNZHCYc",
    "fRDJX32O/TUFLshK03U5w4MtHbZaAllijr0/hYcuy10wTuln+XkaUq4bCtkISi/Nvs+McfABL0inDCQAnnbftu3eO3ENOS3N5qQs",
    "e2DwBgsVq7tvvcRyTtadgC5fxf2lL7GeIDZVGcG9Smk3IZ/VN+Anrkc+k40ToUJfNNmbfvLNhyHfZPPSQnyKIVuze+iqR6DmYz08",
    "n0lNePQOfPUtX30edr4EqKu+2HoluL0izjZXdSZl8qzojQZtCNbI+tsVUuFLUPWiIQ6qmm4FObmUPY6QR7lzNyfHPRbIgyTwtpMH",
    "k4JLFImyTQtLqyhDaiCMoNBKtaa4kez7fmU7A7QwPzsar8J9oErvO/iDlR/1OQDVhGawrjdpiz520hQK0G2r7ccP6m1McCYvzyg/",
    "euIkYkweSBPkmZ/V6zaok1K6bbyK8pUrM078fDIl6fU4i6CXMWp1PGUsORTj4tqN6RgTAH7j9NWAfatmnWcH1Ak7ai5BH1yKjbTY",
    "wE/f/WNo3scZ3qHv2LsJv+xxyTeMj5Vg3Qgs100uSQmLRoDhqqMqqUgIVQX9xbSw39jOqMnFfp8FKU40QJf9fnFRwY7GUIngowzK",
    "wimn/3ZlMERkQT7U3Ghu4IJo+sjwDLEEJjcuHmu9pCmBGAmqVgEozlKhJR94MQV0MOY4gxYDKKN65YM/tdShyfUZDavHGn8AnUqP",
    "RxlkVpBUE8EBE26tvDSWmfR6AXVw1kCekWCwnWrs9EfPvKxlP5c6MbEE0F9EQgmOZ6tE+3DJgRW7h5CRg6s/z95Z8f9oXgazE6ZZ",
    "/x98gKTf6ZzKWaJLFphlBT0tb1ZeLlwCu4UPAo+c7Xt+oRuBVvjKGqNmce5Rs2l75yASEPbI/D8XC5f56cZeNRr1KNXi/e/7W/h/",
    "yWPq5+jVJDXgUstGbPTzvqj3FCyDrx6SoQMjCYS2Fpw5ugsWhuFUys3FoLjRnFuI5ZDRSE+II5nAJB2miUqWZpij9p7ipnac+7cw",
    "8ITK73usNqGto+cGpmsiuUH2rm42E83xTuk0XACAoaJOq8uiiFdt6llWEAdrFrUyhzYD7rC4ewYCi1UP8PUZfeMPmYFiqlTHGN6T",
    "cAoPi0wAi0ZVgLUdIOQDKkcsnWay4DFSJo3gEoVqeRinP3TbHqnsM1aNoFysfR3b3is++e5HxvVo/NoBSlQMa5O8IBSYVpYd1pYf",
    "/CozxddqyEgaY3uzpFFNO8izciIm7oB9n6wL+swglw9VueuBezM6o4gBsUebSRcpRrp/kg2w0Y5BbkwEqLQizsoJKI9ZwaZOaSsn",
    "Yn5uYqA7kdHRJTQTjCM4GjNgRRh2DBoqKIeARlSxU8TIzwMFGFpRCOvghoz7oJfoXkEsPjQnskWjDGoGA1InWCBU7bIYoAXPeNSx",
    "VwzLnQdHklvNOShhHWzgLMmklp/HTqSrsugpPnll8xDiEbruvgry4HrERakYPjE8aoBJlokhcll7ro8kvL5dKvQmi81CJOo1fYge",
    "FYQKIu1HW43cC5y6yHKku13MuqyWhxFq3O3PLSYRQ8+DzexqE303WwDPGXrcfibGgmx2G3w7sVlgE/9aNafh56vR4KaI3A54L+zV",
    "Pzcy3fnTxEjpyF7vPtZi3QB5kVCEGjFCAgsbz/Qr+uwt91j2Fy0aEXuuKlfxv/4+Qdl5RMEnqJl3T3NhDsWgKIQ4Df4GoAec1fe2",
    "eSXbnNZZhBOCne6Q9g3/QADE6D7rB1cxPbH63HUwuLPEExGBCCf7lNLrke1qjBD3rCcbDYcoKVJ7frs23ZPdVNF826C4ayiqvDiF",
    "wRaMNT/d9qLLVpD9RVYj+smN1QjOk3o0a6T/UpscgQbvX72qJo+YNyQ7xjaFtdnc73vA0JrC95aL9/qwyWCEKWDa3L40YRjccvpN",
    "FnxS9mEdSwt/jG33DKf4x7Q4dDG68gTIEUG6nNCFEdPr7NBuzZkcVkCOZB2D0BZCDnjBPcSaNh5jy7XLCYGGxxsbp47OMXsCF3w6",
    "epTOHJBA16MOA968g8Jg7Sp4bisKWb6piuG3ng7JoYyoayBJArVD/0JuRE9qJ6WOeBYhM4T392OVkVkeW75dyYQYzJjaVwfJDjCZ",
    "tO+bEOWJeos8qHKSgOHNnb8ZIzQacheW5D5Sb9ePi5kMjnn2uIZTYerN68fMIw5WpeipgAOFjO5NehNUbWesafpjdLFIAjepnUFy",
    "OvWRn31vp55094OfIxszcsKk38b1SPhQVLvVU5vxqqx6xbHOqPxUT8fDN2OvkENYSluHHwp/dKgQa/8rt1DLQ/NsHwN6GvzUez15",
    "TPoiO3dWP7QyOLL1bLTyURtliZmGgGK8RNeCHj5c0izHHJsm42Q8n8n3NXWPXPjb88dYZFitajlIE3CKSMfHdJwPJnrZ01qgG5fo",
    "qdaSs3xmkaF5/0F/b2Y7Dk49g04FoWcr8BncSgz7wFRdO8fZg1e0suE3RdmbkS2QI5x+Tidtfywd18OCTFA5TeeYGbvutqixCsJE",
    "uphIkBu5RUDVN/dsEQmFXo2r80TVlOQESzbrxrX59wXy36weuGgpR9+6vqARx2kcfEzLJrr83he4vQ6JCKcVU5XhGRMf2z27/FH+",
    "Nx/Pprl0MliXsX62CqGedGtEUQVV+UV5XN2OHvj+bue1S9sGxzN3cECGCsmI760ZeB5My6lz4OSU4TjeIavw0f8l/o+2BlBSBEHv",
    "xk9uBCzsgN2oPa4teA+YJW+PGkvcSZQU55ORBqyL55CWl3tqJ25ezrj+lJtrWSIx9g+O7Bn/cIpd7384hH84n4gX53Za5Ms2Cctj",
    "8QxooBiXn4TmaNytArglz/2yodcat9jFQBDohCIIdf9xsSuM8WNUISZ8qIjEmYPoLVRrpqUROpKH07khBZ08xMrNeI180lmVeSz0",
    "V5fv/nt+JEZ2XjDSaNovnSXNzKtmdBqxfPMT9OCwVC86w37aiJmzka05SO2Xxx4tS3AYbGR5aaUk1mNmlT4/52RRdmBYdvY1Mkpp",
    "f3Nwj5F72c+aQugENBj7j2u0DH4NGP6FCOm8WPhoTzxnEtGyEMjCA4EhU3A4NrdMZG9aHgiq9ICjwhIGAjxwnlskokqHvdUD/kuT",
    "iCGdBfcC6k8X2sppiCKce9zZOukkZKVi1DA0DS1FsmBKIhcq44Ph6HY7uHngg952TqbRIJ7oTVWqVB5GsEFwqrB/meHFcrsfkJZ1",
    "euWgKdgSvx/yz5TymdU67f2FBK7NS9IVvJDFlZvS4IJMXT8Xb1ej4rJocDCLPbk643iP1hBpVhg7UhhayEW2Ki72n5T5J+JsGFwl",
    "wMh3Z/wikMjMgNX+seF96pYNT6sFjVgFzj8mU0pSFm2gcOAKQbR2jsXuPgxkVuB186YD8EW4SGHMMmXRPf2Mgvq0WZ8PB5MTMQ+A",
    "xsjJZ2CyQy3KmMGKCN66fbKw0sLAIboSYj9gB3w/RARVp8LZ2jguw5kDWpC+Lf1rdjQuNXxijDCiB8PY91Uy8wz2fTzxM7ZKcRLH",
    "xG/7UUsX/IwGHc8IlXZKk4DRHUmz3stmbs/sY/WySHloUmVNqqLgso4o+Sy8sPw4wCVAYje+vuQ/SxeiYMQQE3tzJYRFyeNKPXEI",
    "rsvJ2z+CDH+M+I4otBv9PMR1SoZDHWJ5XgqU146mTln6l29XF8I4i/bG4oJGyBERFEc6sswPFNWjQO850QpkgM8dSiKzKMgX1Y1J",
    "584pbtb/YFaJ75Xmix2C5dAKe89Nx1LHVksTM5fiIjXFnMDSrujOzBZK8vEebLavLIDxjbRZWWoT1IAbxEy01D6wAN/G6H17AHZy",
    "tLLy4y7mWuRJaXvqMWz0z5GFT8Wx/ZFVnug/dS4cknEyyMe7NVVn3C6VOfYo3yuzd28YN0thf9JUiAoO26fZFfvA+0OnB07/ApjA",
    "cvefO5OUN5EaE8w9lTNmOlgDsogF4eiqxfhSE0lMsOcvOTT5uVX/2Q==",
  ].join("")
  @base64.decode(encoded[:]) catch {
    _ => b""
  }
}

///|
test "PDF JPX decoder reads a JPEG 2000 codestream" {
  let (image, layout) = @jpx.decode_with_layout(pdf_jpx_test_sample()) catch {
    _ => panic()
  }
  assert_eq(image.width, 128, msg="JPX width")
  assert_eq(image.height, 128, msg="JPX height")
  assert_eq(image.num_components, 1, msg="JPX components")
  assert_true(image.data.length() > 0, msg="JPX samples")
  assert_true(layout.contains("component"), msg="JPX layout")
}

///|
fn pdf_jpx_test_append(out : Array[Byte], text : String) -> Unit {
  out.append(@utf8.encode(text).to_array())
}

///|
fn pdf_jpx_test_offset(value : Int) -> String {
  let text = value.to_string()
  let mut result = ""
  for _ in text.length()..<10 {
    result = result + "0"
  }
  result + text
}

///|
fn pdf_jpx_test_document(image : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let offsets : Array[Int] = []
  pdf_jpx_test_append(out, "%PDF-1.7\n")
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n",
  )
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "4 0 obj\n<< /Type /XObject /Subtype /Image /Width 128 /Height 128 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /JPXDecode /Length \{image.length()} >>\nstream\n",
  )
  out.append(image.to_array())
  pdf_jpx_test_append(out, "\nendstream\nendobj\n")
  let content = "q 100 0 0 100 10 10 cm /Im1 Do Q"
  offsets.push(out.length())
  pdf_jpx_test_append(
    out,
    "5 0 obj\n<< /Length \{content.length()} >>\nstream\n\{content}\nendstream\nendobj\n",
  )
  let xref = out.length()
  pdf_jpx_test_append(out, "xref\n0 \{offsets.length() + 1}\n0000000000 65535 f \n")
  for offset in offsets {
    pdf_jpx_test_append(out, pdf_jpx_test_offset(offset) + " 00000 n \n")
  }
  pdf_jpx_test_append(
    out,
    "trailer\n<< /Size \{offsets.length() + 1} /Root 1 0 R >>\nstartxref\n\{xref}\n%%EOF\n",
  )
  Bytes::from_array(out)
}

///|
fn pdf_jpx_color_test_sample() -> Bytes {
  @base64.decode(
    "AAAADGpQICANCocKAAAAFGZ0eXBqcDIgAAAAAGpwMiAAAAAtanAyaAAAABZpaGRyAAAAEAAAABAAAwcHAAAAAAAPY29scgEAAAAAABAAAACkanAyY/9P/1EALwAAAAAAEAAAABAAAAAAAAAAAAAAABAAAAAQAAAAAAAAAAAAAwcBAQcBAQcBAf9SAAwAAAABAQEEBAAB/1wAB0BASEhQ/2QAJQABQ3JlYXRlZCBieSBPcGVuSlBFRyB2ZXJzaW9uIDIuNS40/5AACgAAAAAAKQAB/5OA2UATzb5yrMs7mmwm2SAslmGYlWdUkWqAgID/2Q=="[:],
  ) catch {
    _ => b""
  }
}

///|
test "PDF JPX all-component decode returns planar RGB samples" {
  let codestream = pdf_jpx_codestream(pdf_jpx_color_test_sample())
  let (image, layout) = @jpx.decode_all_components(codestream) catch {
    _ => panic()
  }
  assert_eq((image.width, image.height), (16, 16), msg="JPX color size")
  assert_eq(image.num_components, 3, msg="JPX color components")
  assert_eq(image.data.length(), 16 * 16 * 3, msg="JPX color planes")
  assert_true(layout.contains("planar"), msg="JPX color layout")
  let (width, height, rgb) = pdf_jpx_rgb(
    pdf_jpx_color_test_sample(),
    Some(PdfRGB),
    false,
  )
  assert_eq((width, height), (16, 16), msg="JPX RGB size")
  assert_eq(rgb.length(), 16 * 16 * 3, msg="JPX RGB samples")
}

///|
test "PDF JPX images accept print colour spaces" {
  let (width, height, rgb) = pdf_jpx_rgb(
    pdf_jpx_color_test_sample(),
    Some(PdfDeviceN(PdfBaseRGB, pdf_default_function(), 3)),
    false,
  )
  assert_eq((width, height), (16, 16), msg="JPX DeviceN size")
  assert_eq(rgb.length(), 16 * 16 * 3, msg="JPX DeviceN samples")
  let (lab_width, lab_height, lab_rgb) = pdf_jpx_rgb(
    pdf_jpx_color_test_sample(),
    Some(PdfLab),
    false,
  )
  assert_eq((lab_width, lab_height), (16, 16), msg="JPX Lab size")
  assert_eq(lab_rgb.length(), 16 * 16 * 3, msg="JPX Lab samples")
}

///|
fn pdf_jpx_test_u32(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 24) & 0xff).to_byte())
  out.push(((value >> 16) & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
test "PDF JP2 boxed codestream is unwrapped" {
  let raw = pdf_jpx_test_sample()
  let out : Array[Byte] = []
  out.append(b"\x00\x00\x00\x0cjP  \r\n\x87\n".to_array())
  pdf_jpx_test_u32(out, raw.length() + 8)
  out.append(b"jp2c".to_array())
  out.append(raw.to_array())
  let (width, height, rgb) = pdf_jpx_rgb(
    Bytes::from_array(out),
    Some(PdfGray),
    false,
  )
  assert_eq((width, height), (128, 128), msg="JP2 dimensions")
  assert_eq(rgb.length(), 128 * 128 * 3, msg="JP2 RGB samples")
}

///|
test "PDF JPX image renders through the graphics document" {
  let document = pdf_graphics_document(
    pdf_jpx_test_document(pdf_jpx_test_sample()),
    no_text_index=true,
  )
  assert_true(document.length() > 0, msg="JPX document bytes")
}
